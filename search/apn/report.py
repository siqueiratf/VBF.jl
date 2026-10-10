"""Export a snapshot of a discovery database as CSV, LaTeX, JSON and publication figures.

Usage: python3 report.py RUN_DIRECTORY [OUTPUT_DIRECTORY]
Uses Python >=3.11 and matplotlib. An active database is read in one SQLite
transaction; the output is explicitly a snapshot, never an experiment verdict.
"""
import csv
import hashlib
import json
import os
import sqlite3
import sys
import tomllib
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


def ortho_spectra(encoded):
    """Recompute plot data from the persisted ortho-derivative, with integer FWHT."""
    lut=list(bytes.fromhex(encoded))
    if len(lut)!=256:raise ValueError('expected an eight-bit ortho-derivative')
    differential=Counter()
    for a in range(1,256):
        counts=[0]*256
        for x in range(256):counts[lut[x]^lut[x^a]]+=1
        differential.update(counts)
    walsh=Counter()
    for b in range(256):
        transform=[1 if (b & y).bit_count()%2==0 else -1 for y in lut]
        width=1
        while width<256:
            for start in range(0,256,2*width):
                for j in range(width):
                    u,v=transform[start+j],transform[start+j+width]
                    transform[start+j],transform[start+j+width]=u+v,u-v
            width*=2
        walsh.update(abs(value) for a,value in enumerate(transform) if (a,b)!=(0,0))
    assert sum(differential.values())==255*256 and sum(walsh.values())==65535
    return dict(sorted(differential.items())),dict(sorted(walsh.items()))


def export_report(run, output):
    output.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(f"file:{(run / 'run.sqlite').resolve()}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    db.execute("BEGIN")
    manifest = tomllib.loads(db.execute("SELECT value FROM metadata WHERE key='run'").fetchone()[0])
    candidates = [tomllib.loads(r[0]) for r in db.execute("SELECT evidence FROM candidates ORDER BY lut_id")]
    units = [dict(r) for r in db.execute("SELECT id,kind,status,direction,result FROM units ORDER BY id")]
    sessions = [dict(r) for r in db.execute("SELECT * FROM sessions ORDER BY id")]
    evaluations = db.execute("SELECT COUNT(*) FROM evaluations").fetchone()[0]
    comparisons = [tomllib.loads(r[0]) for r in db.execute("SELECT evidence FROM comparisons")]
    plan_frozen = db.execute("SELECT 1 FROM metadata WHERE key='plan_complete'").fetchone() is not None
    db.rollback()
    db.close()
    absent = {p['sigma_hash'] for p in candidates if p['evidence_level'] == 'inequivalent_to_documented_quadratic_corpus'}
    quad = {p['sigma_hash'] for p in candidates if p['apn'] and p['quadratic']}
    counts = dict(exact_luts=len(candidates), evaluated_switching_combinations=evaluations,
                  apn_luts=sum(p['apn'] for p in candidates),
                  quadratic_apn_luts=sum(p['apn'] and p['quadratic'] for p in candidates),
                  quadratic_signature_buckets=len(quad), corpus_absent_signature_buckets=len(absent))
    snapshot = dict(created_utc=datetime.now(timezone.utc).isoformat(), manifest=manifest,
                    counts=counts, units=units, sessions=sessions,
                    finite_frozen_plan_exhausted=bool(units) and plan_frozen and all(u['status']=='done' for u in units),
                    novelty_scope='documented quadratic corpus only', literature_novelty='unresolved',
                    all_apn_classification=False, candidates=candidates, comparisons=comparisons)
    (output/'snapshot.json').write_text(json.dumps(snapshot, indent=2))
    fields=['lut_sha256','sigma_hash','apn','algebraic_degree','differential_uniformity','evidence_level','literature_novelty','lut_hex']
    with (output/'candidates.csv').open('w', newline='') as f:
        writer=csv.DictWriter(f, fieldnames=fields, extrasaction='ignore');writer.writeheader();writer.writerows(candidates)
    # A round-trippable seed set for an explicit next exploration stage.
    # Non-APNs and nonquadratic maps remain in the full CSV evidence export.
    with (output/'seeds.tsv').open('w', newline='') as f:
        writer=csv.DictWriter(f, fieldnames=['sigma_hash','lut_hex','lut_sha256'],
                              delimiter='\t', extrasaction='ignore')
        writer.writeheader()
        writer.writerows(p for p in candidates if p['apn'] and p['quadratic'])
    with (output/'relationships.csv').open('w',newline='') as f:
        fields=['candidate_sha256','target_sha256','relation','status','equivalent']
        writer=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');writer.writeheader();writer.writerows(comparisons)
    selected=[]
    for p in candidates:
        if p['evidence_level']=='inequivalent_to_documented_quadratic_corpus' and len(selected)<3:
            dd,walsh=ortho_spectra(p['ortho_lut_hex'])
            # Bind plot values to the v1 tuple-of-ordered-integer-pairs signature.
            display=lambda hist:'['+', '.join(f'{k} => {v}' for k,v in hist.items())+']'
            signature=hashlib.sha256(('('+display(dd)+', '+display(walsh)+')').encode()).hexdigest()
            if signature!=p['sigma_hash']:raise ValueError('plotted spectra disagree with verified signature')
            selected.append(dict(lut_sha256=p['lut_sha256'],sigma_hash=p['sigma_hash'],
                                 ortho_ddt_histogram=dd,ortho_absolute_walsh_histogram=walsh))
    (output/'selected_invariants.json').write_text(json.dumps(selected,indent=2))
    with (output/'counts.tex').open('w') as f:
        f.write('\\begin{tabular}{lr}\nMeasure & Count \\\\\n\\hline\n')
        for key,value in counts.items():
            f.write(key.replace('_',' ')+' & '+f'{value:,}'+ ' \\\\\n')
        f.write('\\end{tabular}\n% Signature buckets are lower bounds on quadratic CCZ classes, not exact classification.\n')
    os.environ.setdefault("MPLCONFIGDIR",str(output/".matplotlib-cache"))
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    with plt.rc_context({'font.size':10,'svg.fonttype':'none','pdf.fonttype':42}):
        fig,ax=plt.subplots(figsize=(7,4), layout='constrained')
        labels=['Exact LUTs','Verified APN LUTs','Quadratic APN LUTs','Quadratic signature buckets','Absent from quadratic reference']
        values=[counts[k] for k in ('exact_luts','apn_luts','quadratic_apn_luts','quadratic_signature_buckets','corpus_absent_signature_buckets')]
        ax.barh(labels[::-1],values[::-1],color='#315b80');ax.set_xlabel('Count (distinct definitions)')
        for i,v in enumerate(values[::-1]):ax.text(v,i,f' {v:,}',va='center')
        ax.set_xlim(0,max([1]+values)*1.2)
        from matplotlib.ticker import MaxNLocator
        ax.xaxis.set_major_locator(MaxNLocator(integer=True))
        ax.set_title('Validated experiment snapshot\nLiterature-wide novelty unresolved')
        for suffix in ('svg','pdf'):fig.savefig(output/f'validation_counts.{suffix}')
        plt.close(fig)
        statuses=Counter(u['status'] for u in units)
        fig,ax=plt.subplots(figsize=(5,3),layout='constrained');ax.bar(list(statuses),list(statuses.values()),color='#315b80')
        ax.set_ylabel('Construction units');ax.set_title('Finite plan coverage (no claim about all APNs)')
        if not statuses:
            ax.text(0.5,0.5,'No construction plan: validation import',ha='center',transform=ax.transAxes)
            ax.set_xticks([])
        for suffix in ('svg','pdf'):fig.savefig(output/f'coverage.{suffix}')
        plt.close(fig)
        if selected:
            fig,axes=plt.subplots(len(selected),2,figsize=(9,3*len(selected)),squeeze=False,layout='constrained')
            for row,p in enumerate(selected):
                for column,(key,label) in enumerate((('ortho_ddt_histogram','Differential multiplicity'),('ortho_absolute_walsh_histogram','Absolute Walsh coefficient'))):
                    ax=axes[row,column];hist=p[key]
                    ax.bar(range(len(hist)),list(hist.values()),color='#315b80')
                    step=max(1,(len(hist)+7)//8)
                    ticks=list(range(0,len(hist),step))
                    if ticks[-1]!=len(hist)-1:ticks.append(len(hist)-1)
                    labels=list(hist)
                    ax.set_xticks(ticks,[labels[i] for i in ticks]);ax.set_xlabel(label);ax.set_ylabel('Frequency pairs')
                    ax.set_title('Ortho-derivative of LUT '+p['lut_sha256'][:12])
            fig.suptitle('Selected corpus-absent quadratic APNs (LUT digest order)\nDDT: a != 0; Walsh: (a,b) != (0,0)')
            for suffix in ('svg','pdf'):fig.savefig(output/f'ortho_spectra.{suffix}')
            plt.close(fig)
    print(json.dumps(counts,indent=2))
    return snapshot


if __name__=='__main__':
    if len(sys.argv) not in (2,3):raise SystemExit('usage: report.py RUN_DIRECTORY [OUTPUT_DIRECTORY]')
    run=Path(sys.argv[1]);export_report(run,Path(sys.argv[2]) if len(sys.argv)==3 else run/'publication')
