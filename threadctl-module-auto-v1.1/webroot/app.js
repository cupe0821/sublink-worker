import {exec,toast,getPackagesInfo} from './kernelsu.js';
const MOD='/data/adb/modules/threadctl_rs_webui';
const BB='/data/adb/ksu/bin/busybox';
const CLASSIFIER_VERSION='3';
const profiles=['game','chat','video','launcher','audio','balanced','power-save'];
let apps=[];let overrides=new Map();let labels=new Map();
const $=id=>document.getElementById(id);
async function sh(c){const r=await exec(c);if(r.errno!==0)throw new Error(r.stderr||`errno=${r.errno}`);return r.stdout||''}
function b64(s){const a=new TextEncoder().encode(s);let x='';for(let i=0;i<a.length;i+=0x8000)x+=String.fromCharCode(...a.subarray(i,i+0x8000));return btoa(x)}
async function writeFile(path,text){const v=b64(text);await sh(`printf '%s' '${v}' | '${BB}' base64 -d > '${path}.tmp' && mv -f '${path}.tmp' '${path}'`)}
function parseTsv(s){return s.split(/\r?\n/).filter(Boolean).map(x=>x.split('\t'))}
function parseApps(s){return parseTsv(s).map(x=>({pkg:x[0],base:x[1]||'balanced',reason:x[2]||'',seen:x[3]||'',ver:x[4]||''})).filter(x=>x.pkg)}
function labelText(){return [...labels.entries()].sort((a,b)=>a[0].localeCompare(b[0])).map(([p,l])=>`${p}\t${String(l).replace(/[\t\r\n]+/g,' ')}`).join('\n')+(labels.size?'\n':'')}
async function refreshLabelsAndRepair(oldCache){
  try{
    for(let i=0;i<apps.length;i+=80){const info=getPackagesInfo(apps.slice(i,i+80).map(x=>x.pkg))||[];for(const p of info)if(p&&p.packageName)labels.set(p.packageName,p.appLabel||p.packageName)}
    const next=labelText();
    if(next!==oldCache){
      await writeFile(`${MOD}/config/labels.tsv`,next);
      await sh(`/system/bin/sh '${MOD}/scripts/reclassify-legacy.sh' --all`);
      const auto2=await sh(`cat '${MOD}/config/auto-apps.tsv' 2>/dev/null || true`);
      apps=parseApps(auto2);
    }
  }catch(_){/* label cache is optional; package/category/runtime signals still work */}
}
async function load(){
  const [st,auto,ov,cur,adv,en,labelCache]=await Promise.all([
    sh(`'${MOD}/scripts/status.sh' 2>/dev/null || true`),
    sh(`cat '${MOD}/config/auto-apps.tsv' 2>/dev/null || true`),
    sh(`cat '${MOD}/config/overrides.tsv' 2>/dev/null || true`),
    sh(`cat '${MOD}/run/current.tsv' 2>/dev/null || true`),
    sh(`cat '${MOD}/config/advanced.kdl' 2>/dev/null || true`),
    sh(`cat '${MOD}/config/auto.enabled' 2>/dev/null || echo 1`),
    sh(`cat '${MOD}/config/labels.tsv' 2>/dev/null || true`)
  ]);
  const daemon=/threadctl=running/.test(st),ctl=/auto=running/.test(st);
  $('daemon').textContent=daemon?'运行中':'已停止';$('autoState').textContent=ctl?'运行中':'已停止';$('dot').className='dot '+(daemon&&ctl?'ok':'bad');
  $('enabled').checked=en.trim()!=='0';
  apps=parseApps(auto);
  overrides=new Map(parseTsv(ov).filter(x=>x[0]&&x[1]).map(x=>[x[0],x[1]]));
  labels=new Map(parseTsv(labelCache).filter(x=>x[0]&&x[1]).map(x=>[x[0],x[1]]));
  $('advanced').value=adv;
  await refreshLabelsAndRepair(labelCache);
  $('count').textContent=String(apps.length);
  $('pending').textContent=String(apps.filter(a=>a.ver!==CLASSIFIER_VERSION||/^classifier-(fallback|error|transient)/.test(a.reason)||/^(migrated-v1\.0|migration-v1\.0|legacy-import)$/.test(a.reason)).length);
  renderCurrent(cur);renderApps();
}
function renderCurrent(cur){const x=parseTsv(cur)[0]||[];const pkg=x[0]||'';const prof=x[1]||'';const why=x[2]||'';const box=$('currentBox');if(!pkg){box.innerHTML='<strong>等待前台应用…</strong>';return}const label=labels.get(pkg)||pkg;box.innerHTML='';const s=document.createElement('strong');s.textContent=label;const sm=document.createElement('small');sm.textContent=pkg;const p=document.createElement('span');p.className='pill';p.textContent=`${prof} · ${why}`;box.append(s,sm,p)}
function renderApps(){const q=$('search').value.trim().toLowerCase();const root=$('apps');root.innerHTML='';const list=apps.filter(a=>(labels.get(a.pkg)||a.pkg).toLowerCase().includes(q)||a.pkg.toLowerCase().includes(q));if(!list.length){root.innerHTML='<p>还没有记录。打开任意应用后会自动出现。</p>';return}for(const a of list){const row=document.createElement('div');row.className='app';const info=document.createElement('div');const n=document.createElement('strong');n.textContent=labels.get(a.pkg)||a.pkg;const sm=document.createElement('small');const stale=a.ver!==CLASSIFIER_VERSION?' · 待重判':'';sm.textContent=`${a.pkg} · 自动: ${a.base} · ${a.reason} · v${a.ver||'旧'}${stale}`;info.append(n,sm);const sel=document.createElement('select');const o0=document.createElement('option');o0.value='';o0.textContent=`自动 (${a.base})`;sel.append(o0);for(const p of profiles){const o=document.createElement('option');o.value=p;o.textContent=p;sel.append(o)}sel.value=overrides.get(a.pkg)||'';sel.addEventListener('change',()=>saveOverride(a.pkg,sel.value));row.append(info,sel);root.append(row)}}
async function saveOverride(pkg,val){if(val)overrides.set(pkg,val);else overrides.delete(pkg);const text=[...overrides.entries()].sort((a,b)=>a[0].localeCompare(b[0])).map(([p,v])=>`${p}\t${v}`).join('\n')+(overrides.size?'\n':'');try{await writeFile(`${MOD}/config/overrides.tsv`,text);await sh(`/system/bin/sh '${MOD}/scripts/rebuild-config.sh' && /system/bin/sh '${MOD}/scripts/auto-controller.sh' --once`);toast('策略覆盖已应用');await load()}catch(e){toast('保存失败')}}
$('search').addEventListener('input',renderApps);
$('refresh').addEventListener('click',load);
$('reclassify').addEventListener('click',async()=>{try{toast('正在重新识别全部自动记录…');await sh(`/system/bin/sh '${MOD}/scripts/reclassify-legacy.sh' --all`);toast('重新识别完成');await load()}catch(e){toast('重新识别失败')}});
$('restart').addEventListener('click',async()=>{try{await sh(`'${MOD}/scripts/restart.sh'`);toast('服务已重启');await load()}catch(e){toast('重启失败')}});
$('enabled').addEventListener('change',async e=>{try{await writeFile(`${MOD}/config/auto.enabled`,e.target.checked?'1\n':'0\n');toast(e.target.checked?'自动模式已开启':'自动模式已关闭')}catch(_){toast('切换失败')}});
$('saveAdvanced').addEventListener('click',async()=>{try{await writeFile(`${MOD}/config/advanced.kdl`,$('advanced').value);await sh(`/system/bin/sh '${MOD}/scripts/rebuild-config.sh'`);toast('高级 KDL 已保存，原版 daemon 将热加载')}catch(e){toast('保存失败')}});
$('loadKdl').addEventListener('click',async()=>{$('output').textContent=await sh(`cat '${MOD}/config/threadctl.kdl' 2>/dev/null || true`)});
$('loadLog').addEventListener('click',async()=>{$('output').textContent=await sh(`echo '=== threadctl ==='; tail -n 100 '${MOD}/run/threadctl.log' 2>/dev/null; echo; echo '=== auto ==='; tail -n 160 '${MOD}/run/auto.log' 2>/dev/null`)});
load().catch(e=>{$('currentBox').textContent='初始化失败: '+e.message});
