//! Read a CSR export (see the export README): binary CSR files and nodes.parquet.

use parquet::column::reader::{get_typed_column_reader, ColumnReader};
use parquet::data_type::{BoolType, ByteArrayType, DataType, FixedLenByteArrayType, Int32Type, Int64Type};
use parquet::file::reader::{FileReader, SerializedFileReader};
use std::fs::File;
use std::path::Path;

pub type Result<T> = std::result::Result<T, String>;

pub struct Export {
    pub n: usize,
    pub offsets: Vec<u64>,
    pub targets: Vec<u32>,
    pub methods: Vec<u8>,
    pub class_id: Vec<u32>,
    pub sha: Vec<[u8; 32]>,
    pub is_seed: Vec<bool>,
    pub source: Vec<String>,
    pub v5_returns: Vec<u32>,
    pub switching_returns: Vec<u32>,
    /// (two, three) or None when the class has no measured features.
    pub features: Vec<Option<(i64, i64)>>,
    pub manifest: serde_json::Value,
}

fn read_le<const W: usize, T>(path: &Path, f: fn([u8; W]) -> T) -> Result<Vec<T>> {
    let bytes = std::fs::read(path).map_err(|e| format!("{}: {e}", path.display()))?;
    if bytes.len() % W != 0 {
        return Err(format!("{}: size is not a multiple of {W}", path.display()));
    }
    Ok(bytes.chunks_exact(W).map(|c| f(c.try_into().unwrap())).collect())
}

/// Read one whole column, all row groups. None marks a null.
fn column<T: DataType>(r: &SerializedFileReader<File>, name: &str) -> Result<Vec<Option<T::T>>>
where
    T::T: Clone,
{
    let meta = r.metadata();
    let schema = meta.file_metadata().schema_descr();
    let index = (0..schema.num_columns())
        .find(|&i| schema.column(i).path().string() == name)
        .ok_or(format!("nodes.parquet: no column {name}"))?;
    let mut out = Vec::with_capacity(meta.file_metadata().num_rows() as usize);
    for g in 0..meta.num_row_groups() {
        let group = r.get_row_group(g).map_err(|e| e.to_string())?;
        let rows = meta.row_group(g).num_rows() as usize;
        let col: ColumnReader = group.get_column_reader(index).map_err(|e| e.to_string())?;
        let mut reader = get_typed_column_reader::<T>(col);
        let (mut defs, mut values) = (Vec::new(), Vec::new());
        let mut read = 0;
        while read < rows {
            let (records, _, _) = reader
                .read_records(rows - read, Some(&mut defs), None, &mut values)
                .map_err(|e| e.to_string())?;
            if records == 0 {
                break;
            }
            read += records;
        }
        if read != rows || defs.len() != rows {
            return Err(format!("nodes.parquet: short column {name}"));
        }
        let mut it = values.into_iter();
        for d in defs {
            out.push(if d > 0 { it.next() } else { None });
        }
    }
    Ok(out)
}

fn required<T>(v: Vec<Option<T>>, name: &str) -> Result<Vec<T>> {
    v.into_iter().map(|x| x.ok_or(format!("nodes.parquet: null in {name}"))).collect()
}

pub fn read(dir: &Path) -> Result<Export> {
    let manifest: serde_json::Value = serde_json::from_slice(
        &std::fs::read(dir.join("manifest.json")).map_err(|e| format!("manifest.json: {e}"))?,
    )
    .map_err(|e| format!("manifest.json: {e}"))?;
    let offsets = read_le(&dir.join("out.offsets.u64"), u64::from_le_bytes)?;
    let targets = read_le(&dir.join("out.targets.u32"), u32::from_le_bytes)?;
    let methods = std::fs::read(dir.join("out.methods.u8")).map_err(|e| format!("out.methods.u8: {e}"))?;
    let n = offsets.len().checked_sub(1).ok_or("empty offsets")?;
    if offsets[0] != 0 || offsets[n] as usize != targets.len() || methods.len() != targets.len() {
        return Err("CSR files are inconsistent".into());
    }
    for v in 0..n {
        let row = &targets[offsets[v] as usize..offsets[v + 1] as usize];
        if offsets[v] > offsets[v + 1]
            || row.windows(2).any(|w| w[0] >= w[1])
            || row.iter().any(|&t| t as usize >= n || t as usize == v)
        {
            return Err(format!("CSR row {v} is not sorted, unique and loop-free"));
        }
    }
    if methods.iter().any(|&m| m == 0 || m > 3) {
        return Err("out.methods.u8 has a value outside 1..3".into());
    }

    let r = SerializedFileReader::new(File::open(dir.join("nodes.parquet")).map_err(|e| e.to_string())?)
        .map_err(|e| e.to_string())?;
    if r.metadata().file_metadata().num_rows() as usize != n {
        return Err("nodes.parquet row count differs from the CSR".into());
    }
    let u32s = |name: &str| -> Result<Vec<u32>> {
        Ok(required(column::<Int32Type>(&r, name)?, name)?.into_iter().map(|x| x as u32).collect())
    };
    let vertex = u32s("vertex")?;
    if vertex.iter().enumerate().any(|(i, &v)| v as usize != i) {
        return Err("nodes.parquet is not ordered by vertex".into());
    }
    let class_id = u32s("class_id")?;
    let (out_degree, in_degree) = (u32s("out_degree")?, u32s("in_degree")?);
    let mut incoming = vec![0u32; n];
    for &t in &targets {
        incoming[t as usize] += 1;
    }
    for v in 0..n {
        if out_degree[v] as u64 != offsets[v + 1] - offsets[v] || in_degree[v] != incoming[v] {
            return Err(format!("degree of vertex {v} differs from the CSR"));
        }
    }
    let sha = required(column::<FixedLenByteArrayType>(&r, "lut_sha256")?, "lut_sha256")?
        .into_iter()
        .map(|b| <[u8; 32]>::try_from(b.data()).map_err(|_| "lut_sha256 is not 32 bytes".to_string()))
        .collect::<Result<Vec<_>>>()?;
    let source = required(column::<ByteArrayType>(&r, "source")?, "source")?
        .into_iter()
        .map(|b| String::from_utf8(b.data().to_vec()).map_err(|_| "source is not UTF-8".to_string()))
        .collect::<Result<Vec<_>>>()?;
    let two = column::<Int64Type>(&r, "two")?;
    let three = column::<Int64Type>(&r, "three")?;
    let features = two.into_iter().zip(three).map(|(a, b)| a.zip(b)).collect();
    Ok(Export {
        n,
        class_id,
        sha,
        is_seed: required(column::<BoolType>(&r, "is_seed")?, "is_seed")?,
        source,
        v5_returns: u32s("v5_self_loops")?,
        switching_returns: u32s("switching_self_loops")?,
        features,
        offsets,
        targets,
        methods,
        manifest,
    })
}
