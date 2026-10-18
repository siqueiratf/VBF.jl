'use strict';
(() => {
  const $ = id => document.getElementById(id);
  const number = value => Number(value).toLocaleString();
  const canvas = $('graph'), message = $('message');
  const gl = canvas.getContext('webgl2', {antialias:false, alpha:false, powerPreference:'low-power'});
  if (!gl) { message.textContent = 'This graph needs WebGL 2. Enable hardware acceleration or use a browser with WebGL support.'; return; }
  const mask = 0x3fffffff;
  let manifest, positions, edges, flags, width, textureHeight, positionTexture, flagTexture;
  let pointProgram, edgeProgram, arrowProgram, edgeVAO, localVAO, localBuffer;
  let selected = -1, neighbors = [], localEdges = new Uint32Array(), metadata = new Map();
  let center = [0,0], zoom = 0.85, ready = false, framePending = false, drag = null;
  let drawMilliseconds = 0;
  const palette = () => matchMedia('(prefers-color-scheme: dark)').matches
    ? {background:[0.067,0.098,0.09], seed:[1,0.765,0.416], found:[0.412,0.725,0.8], edge:[0.48,0.65,0.62], switching:[0.79,0.64,0.96]}
    : {background:[0.957,0.961,0.949], seed:[0.64,0.36,0], found:[0.14,0.46,0.6], edge:[0.18,0.35,0.28], switching:[0.47,0.26,0.7]};
  const common = `
    precision highp float; precision highp int;
    uniform highp sampler2D uPositions;
    uniform highp usampler2D uFlags;
    uniform int uTextureWidth; uniform vec2 uCenter; uniform vec2 uResolution;
    uniform float uZoom; uniform float uDPR; uniform bool uLocal;
    ivec2 address(uint id) { return ivec2(int(id)%uTextureWidth,int(id)/uTextureWidth); }
    vec2 project(uint id) { vec2 p=texelFetch(uPositions,address(id),0).xy; return (p-uCenter)*uZoom*vec2(uResolution.y/uResolution.x,1.); }
    uint flag(uint id) { return texelFetch(uFlags,address(id),0).r; }
  `;
  function program(vertex, fragment) {
    const compile = (type, source) => {
      const shader = gl.createShader(type); gl.shaderSource(shader, source); gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader));
      return shader;
    };
    const p = gl.createProgram();
    gl.attachShader(p,compile(gl.VERTEX_SHADER,vertex)); gl.attachShader(p,compile(gl.FRAGMENT_SHADER,fragment)); gl.linkProgram(p);
    if (!gl.getProgramParameter(p,gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
    return p;
  }
  function edgeVertex(arrows=false) {
    return `#version 300 es
      ${common}
      layout(location=0) in uvec2 aEdge;
      uniform bool uV5; uniform bool uSwitching; uniform int uSelected;
      flat out uint vKind; out float vDistance; flat out float vHighlight;
      void main() {
        uint a=aEdge.x,b=aEdge.y&0x3fffffffu; vKind=aEdge.y>>31;
        bool both=(aEdge.y&0x40000000u)!=0u;
        bool visible=(vKind==0u?uV5:uSwitching) && (!uLocal || ((flag(a)&6u)!=0u && (flag(b)&6u)!=0u));
        vec2 p=project(a),q=project(b); vec2 delta=(q-p)*uResolution*.5;
        float len=length(delta); vec2 direction=delta/max(len,.001); vec2 normal=vec2(-direction.y,direction.x);
        vec2 offset=both?normal*(vKind==0u?-2.:2.)*uDPR*2./uResolution:vec2(0.);
        vHighlight=(int(a)==uSelected||int(b)==uSelected)?1.:0.;
        ${arrows ? `
          visible=visible && len>14.*uDPR;
          vec2 tip=q-direction*4.*uDPR*2./uResolution;
          vec2 base=q-direction*12.*uDPR*2./uResolution;
          vec2 point=gl_VertexID==0?tip:base+normal*(gl_VertexID==1?3.:-3.)*uDPR*2./uResolution;
          gl_Position=visible?vec4(point+offset,0.,1.):vec4(3.,3.,0.,1.); vDistance=0.;
        ` : `
          gl_Position=visible?vec4((gl_VertexID==0?p:q)+offset,0.,1.):vec4(3.,3.,0.,1.);
          vDistance=gl_VertexID==0?0.:len;
        `}
      }`;
  }
  function edgeFragment(arrows=false) {
    return `#version 300 es
      precision highp float; precision highp int;
      flat in uint vKind; in float vDistance; flat in float vHighlight;
      uniform vec3 uEdgeColor; uniform vec3 uSwitchColor; uniform float uOpacity; uniform float uDPR;
      uniform int uSelected; uniform bool uLocal; out vec4 color;
      void main() {
        ${arrows ? '' : 'if(vKind==1u && mod(vDistance/uDPR,12.)>6.) discard;'}
        float opacity=${arrows ? '.95' : 'vHighlight>.5?.85:(uLocal?.45:uOpacity*(uSelected>=0?.35:1.))'};
        color=vec4(vKind==0u?uEdgeColor:uSwitchColor,opacity);
      }`;
  }
  function initializePrograms() {
    pointProgram = program(`#version 300 es
      ${common}
      uniform vec3 uSeedColor; uniform vec3 uFoundColor; out vec3 vColor; out float vAlpha;
      void main() {
        uint id=uint(gl_VertexID),f=flag(id); bool near=(f&6u)!=0u;
        vec2 p=project(id); gl_Position=uLocal&&!near?vec4(3.,3.,0.,1.):vec4(p,0.,1.);
        float radius=(f&1u)!=0u?3.:1.6;
        if(near) radius=4.; if((f&4u)!=0u) radius=8.;
        gl_PointSize=min(12.,radius+max(0.,log2(uZoom))*.2)*uDPR;
        vColor=(f&1u)!=0u?uSeedColor:uFoundColor;
        if((f&4u)!=0u) vColor=vec3(1.,.35,.3);
        vAlpha=near?1.:((f&1u)!=0u?.95:.66);
      }`, `#version 300 es
      precision highp float; in vec3 vColor; in float vAlpha; out vec4 color;
      void main(){float d=length(gl_PointCoord-vec2(.5)); if(d>.5) discard; color=vec4(vColor,vAlpha*(1.-smoothstep(.35,.5,d)));}`);
    edgeProgram = program(edgeVertex(),edgeFragment());
    arrowProgram = program(edgeVertex(true),edgeFragment(true));
  }
  function edgeArray(data, dynamic=false) {
    const vao=gl.createVertexArray(),buffer=gl.createBuffer(); gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER,buffer); gl.bufferData(gl.ARRAY_BUFFER,data,dynamic?gl.DYNAMIC_DRAW:gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0); gl.vertexAttribIPointer(0,2,gl.UNSIGNED_INT,8,0); gl.vertexAttribDivisor(0,1);
    gl.bindVertexArray(null); return {vao,buffer};
  }
  function setUniforms(p, colors) {
    gl.useProgram(p);
    const uniform=name=>gl.getUniformLocation(p,name);
    gl.uniform1i(uniform('uPositions'),0); gl.uniform1i(uniform('uFlags'),1);
    gl.uniform1i(uniform('uTextureWidth'),width); gl.uniform2fv(uniform('uCenter'),center);
    gl.uniform2f(uniform('uResolution'),canvas.width,canvas.height); gl.uniform1f(uniform('uZoom'),zoom);
    gl.uniform1f(uniform('uDPR'),devicePixelRatio); gl.uniform1i(uniform('uLocal'),$('local').checked);
    gl.uniform1i(uniform('uV5'),$('v5').checked); gl.uniform1i(uniform('uSwitching'),$('switching').checked);
    gl.uniform1i(uniform('uSelected'),selected); gl.uniform1f(uniform('uOpacity'),Number($('opacity').value)/100);
    gl.uniform3fv(uniform('uSeedColor'),colors.seed); gl.uniform3fv(uniform('uFoundColor'),colors.found);
    gl.uniform3fv(uniform('uEdgeColor'),colors.edge); gl.uniform3fv(uniform('uSwitchColor'),colors.switching);
  }
  function draw() {
    framePending=false; if(!ready) return;
    const started=performance.now(), colors=palette();
    const rect=canvas.getBoundingClientRect();
    const w=Math.max(1,Math.round(rect.width*devicePixelRatio)),h=Math.max(1,Math.round(rect.height*devicePixelRatio));
    if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}
    gl.viewport(0,0,w,h); gl.clearColor(...colors.background,1); gl.clear(gl.COLOR_BUFFER_BIT);
    gl.enable(gl.BLEND); gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D,positionTexture);
    gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D,flagTexture);
    const local=$('local').checked;
    if(Number($('opacity').value)>0){
      setUniforms(edgeProgram,colors);gl.bindVertexArray(local?localVAO:edgeVAO);
      gl.drawArraysInstanced(gl.LINES,0,2,(local?localEdges.length:edges.length)/2);
      if(selected>=0){setUniforms(arrowProgram,colors);gl.bindVertexArray(localVAO);gl.drawArraysInstanced(gl.TRIANGLES,0,3,localEdges.length/2);}
    }
    setUniforms(pointProgram,colors);gl.bindVertexArray(null);gl.drawArrays(gl.POINTS,0,manifest.nodes);
    drawMilliseconds=performance.now()-started;
    window.apnGraphState={ready:true,nodes:manifest.nodes,edges:edges.length/2,selected:selected+1,zoom,drawMilliseconds,localEdges:localEdges.length/2,webglError:gl.getError()};
  }
  function scheduleDraw(){if(!framePending){framePending=true;requestAnimationFrame(draw);}}
  function fit(ids=null) {
    if(!ready) return;
    let minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity;
    const values=ids||Array.from({length:manifest.nodes},(_,i)=>i);
    for(const id of values){const x=positions[id*2],y=positions[id*2+1];minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);}
    center=[(minX+maxX)/2,(minY+maxY)/2];
    const rect=canvas.getBoundingClientRect();zoom=1.8/Math.max(maxY-minY,(maxX-minX)*rect.height/rect.width,.005);
    zoom=Math.min(zoom,150);scheduleDraw();
  }
  function uploadFlags(){
    const padded=new Uint8Array(width*textureHeight);padded.set(flags);
    gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,flagTexture);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT,1);gl.texImage2D(gl.TEXTURE_2D,0,gl.R8UI,width,textureHeight,0,gl.RED_INTEGER,gl.UNSIGNED_BYTE,padded);
  }
  async function select(id, focus=false) {
    if(!ready||!Number.isInteger(id)||id<0||id>=manifest.nodes) return;
    selected=id;const related=new Map();
    for(let i=0;i<flags.length;i++) flags[i]&=1;
    flags[id]|=4;
    for(let i=0;i<edges.length;i+=2){
      const a=edges[i],b=edges[i+1]&mask,kind=edges[i+1]>>>31;
      if(a!==id&&b!==id)continue;
      const other=a===id?b:a;flags[other]|=2;
      related.set(other,(related.get(other)||0)|(kind===0?1:2));
    }
    neighbors=[...related.keys()].sort((a,b)=>a-b);
    const local=[];
    for(let i=0;i<edges.length;i+=2) if((flags[edges[i]]&6)&&(flags[edges[i+1]&mask]&6))local.push(edges[i],edges[i+1]);
    localEdges=new Uint32Array(local);gl.bindBuffer(gl.ARRAY_BUFFER,localBuffer);gl.bufferData(gl.ARRAY_BUFFER,localEdges,gl.DYNAMIC_DRAW);uploadFlags();
    $('node-title').textContent='Class #'+number(id+1);$('find-id').value=id+1;$('fit-neighbors').hidden=false;
    $('node-info').textContent='Loading class details…';$('neighbors').replaceChildren();
    for(const other of neighbors.slice(0,80)){
      const button=document.createElement('button'),method=related.get(other);
      button.textContent='#'+number(other+1)+(method===1?' · V5':method===2?' · neighbour':' · both');
      button.addEventListener('click',()=>select(other,true));$('neighbors').append(button);
    }
    if(focus) fit([id,...neighbors]);else scheduleDraw();
    try{
      const chunk=Math.floor(id/manifest.metadata_chunk_size);
      if(!metadata.has(chunk))metadata.set(chunk,await requestJSON('/graph-data/'+manifest.version+'/nodes-'+chunk+'.json'));
      if(selected!==id)return;
      const info=metadata.get(chunk)[id%manifest.metadata_chunk_size];
      $('node-info').replaceChildren();
      for(const value of [info.is_seed?'Published seed':'Discovered quadratic class',info.source||'',number(info.incoming)+' incoming · '+number(info.outgoing)+' outgoing classes',number(neighbors.length)+' connected classes · component #'+number(info.component),number(info.v5_returns)+' V5 same-class returns · '+number(info.switching_returns)+' neighbour returns']){
        if(!value)continue;const p=document.createElement('p');p.textContent=value;$('node-info').append(p);
      }
      const hash=document.createElement('code');hash.textContent=info.sha256;$('node-info').append(hash);
      if(neighbors.length>80){const note=document.createElement('p');note.className='small';note.textContent='First 80 neighbours listed; all are included in the graph.';$('node-info').append(note);}
    }catch(error){$('node-info').textContent='Class details unavailable. A newer snapshot may be ready; reload the graph.';}
  }
  async function requestJSON(url){const response=await fetch(url,{cache:'no-store'});if(!response.ok)throw new Error('HTTP '+response.status);return response.json();}
  async function binary(name){const response=await fetch('/graph-data/'+manifest.version+'/'+name);if(!response.ok)throw new Error('Graph data unavailable; reload the page.');return response.arrayBuffer();}
  async function load() {
    try{
      manifest=await requestJSON('/api/graph');if(manifest.schema!=='vbfsearch-class-graph-v1')throw new Error('Unsupported graph snapshot.');
      $('summary').textContent=number(manifest.nodes)+' classes · '+number(manifest.seeds)+' published seeds · '+number(manifest.v5_edges)+' V5 + '+number(manifest.switching_edges)+' neighbour edges';
      $('snapshot').textContent='Snapshot '+new Date(manifest.snapshot_utc).toLocaleString();
      $('refresh-policy').textContent='A new snapshot is built after '+number(manifest.refresh_every_completions)+' completed seeds or parents, with at least '+number(manifest.minimum_refresh_seconds/60)+' minutes between builds. This view stays fixed while you explore.';
      $('compute-cost').textContent='Last snapshot: '+manifest.compute_seconds.toFixed(1)+' seconds to compute; '+number(manifest.components)+' observed connected components. Largest: '+number(manifest.largest_component)+' classes.';
      message.textContent='Downloading '+(manifest.payload_bytes/1048576).toFixed(1)+' MB of cached graph data…';
      const data=await Promise.all([binary('positions.bin'),binary('edges.bin'),binary('flags.bin')]);
      positions=new Float32Array(data[0]);edges=new Uint32Array(data[1]);flags=new Uint8Array(data[2]);
      if(positions.length!==manifest.nodes*2||flags.length!==manifest.nodes||edges.length!==(manifest.v5_edges+manifest.switching_edges)*2)throw new Error('Incomplete graph data.');
      initializePrograms();width=2**Math.ceil(Math.log2(Math.sqrt(manifest.nodes)));textureHeight=Math.ceil(manifest.nodes/width);
      if(Math.max(width,textureHeight)>gl.getParameter(gl.MAX_TEXTURE_SIZE))throw new Error('This graph exceeds your GPU texture limit.');
      positionTexture=gl.createTexture();gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,positionTexture);
      for(const parameter of [gl.TEXTURE_MIN_FILTER,gl.TEXTURE_MAG_FILTER])gl.texParameteri(gl.TEXTURE_2D,parameter,gl.NEAREST);
      const padded=new Float32Array(width*textureHeight*2);padded.set(positions);gl.texImage2D(gl.TEXTURE_2D,0,gl.RG32F,width,textureHeight,0,gl.RG,gl.FLOAT,padded);
      flagTexture=gl.createTexture();gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,flagTexture);
      for(const parameter of [gl.TEXTURE_MIN_FILTER,gl.TEXTURE_MAG_FILTER])gl.texParameteri(gl.TEXTURE_2D,parameter,gl.NEAREST);uploadFlags();
      edgeVAO=edgeArray(edges).vao;const local=edgeArray(new Uint32Array(),true);localVAO=local.vao;localBuffer=local.buffer;
      ready=true;fit();message.hidden=true;$('find-id').max=manifest.nodes;
      const initial=Number(new URLSearchParams(location.search).get('id'));if(Number.isInteger(initial)&&initial>0)await select(initial-1,true);
      window.apnGraph={select:id=>select(id-1,true),fit,manifest};
    }catch(error){console.error(error);message.textContent=error.message.startsWith('HTTP')?'The first cached graph is being prepared. This page will retry shortly.':error.message;if(!ready)setTimeout(load,15000);}
  }
  canvas.addEventListener('pointerdown',event=>{if(!ready)return;canvas.setPointerCapture(event.pointerId);drag={x:event.clientX,y:event.clientY,center:[...center],moved:false};canvas.classList.add('dragging');});
  canvas.addEventListener('pointermove',event=>{
    if(!drag)return;const dx=event.clientX-drag.x,dy=event.clientY-drag.y;if(Math.hypot(dx,dy)>3)drag.moved=true;
    const height=canvas.getBoundingClientRect().height;center=[drag.center[0]-dx*2/(height*zoom),drag.center[1]+dy*2/(height*zoom)];scheduleDraw();
  });
  canvas.addEventListener('pointerup',event=>{
    if(!drag)return;const click=!drag.moved;drag=null;canvas.classList.remove('dragging');
    if(!click)return;const rect=canvas.getBoundingClientRect(),x=event.clientX-rect.left,y=event.clientY-rect.top;
    let best=-1,distance=100;
    for(let id=0;id<manifest.nodes;id++){
      if($('local').checked&&!(flags[id]&6))continue;
      const px=(positions[id*2]-center[0])*zoom*rect.height/2+rect.width/2,py=rect.height/2-(positions[id*2+1]-center[1])*zoom*rect.height/2;
      const d=(x-px)**2+(y-py)**2;if(d<distance){distance=d;best=id;}
    }
    if(best>=0)select(best);
  });
  canvas.addEventListener('pointercancel',()=>{drag=null;canvas.classList.remove('dragging');});
  canvas.addEventListener('wheel',event=>{
    if(!ready)return;event.preventDefault();const rect=canvas.getBoundingClientRect(),x=(event.clientX-rect.left-rect.width/2)*2/rect.height,y=-(event.clientY-rect.top-rect.height/2)*2/rect.height;
    const next=Math.max(.02,Math.min(100000,zoom*Math.exp(-event.deltaY*.0015)));
    center=[center[0]+x*(1/zoom-1/next),center[1]+y*(1/zoom-1/next)];zoom=next;scheduleDraw();
  },{passive:false});
  $('fit').onclick=()=>fit();$('zoom-in').onclick=()=>{zoom*=1.5;scheduleDraw();};$('zoom-out').onclick=()=>{zoom/=1.5;scheduleDraw();};
  $('fit-neighbors').onclick=()=>fit([selected,...neighbors]);
  for(const id of ['v5','switching','opacity','local'])$(id).addEventListener('input',scheduleDraw);
  $('find').onclick=()=>select(Number($('find-id').value)-1,true);
  $('find-id').addEventListener('keydown',event=>{if(event.key==='Enter')$('find').click();});
  $('new-snapshot').onclick=()=>location.reload();
  new ResizeObserver(scheduleDraw).observe(canvas);matchMedia('(prefers-color-scheme: dark)').addEventListener('change',scheduleDraw);
  canvas.addEventListener('webglcontextlost',event=>{event.preventDefault();ready=false;message.hidden=false;message.textContent='The graphics context was lost. Reload to restore the cached graph.';});
  setInterval(async()=>{try{const current=await requestJSON('/api/graph');$('new-snapshot').hidden=!manifest||current.version===manifest.version;}catch{}},30000);
  load();
})();
