import { exec, toast, listPackages, getPackagesInfo } from './kernelsu.js';

const MODDIR = '/data/adb/modules/threadctl_rs_webui';
const BB = '/data/adb/ksu/bin/busybox';
const PROFILES = ['game','chat','video','launcher','audio','balanced','power-save'];

const $ = id => document.getElementById(id);
let appItems = [];
let configured = new Map();
let appsDirty = false;
let advancedOriginal = '';

function validPkg(pkg){ return /^[A-Za-z0-9._]+$/.test(pkg); }
function notify(s){ try{ toast(s); }catch(_){} }

async function shell(cmd){
  const r = await exec(cmd);
  if(r.errno !== 0) throw new Error((r.stderr || `errno=${r.errno}`).trim());
  return r.stdout || '';
}

function b64(text){
  const bytes = new TextEncoder().encode(text);
  let raw = '';
  for(let i=0;i<bytes.length;i+=0x8000) raw += String.fromCharCode(...bytes.subarray(i,i+0x8000));
  return btoa(raw);
}

async function writeText(path,text,backup=false){
  const data = b64(text);
  const bak = backup ? `[ -f '${path}' ] && cp -af '${path}' '${path}.bak' || true; ` : '';
  await shell(`${bak}printf '%s' '${data}' | '${BB}' base64 -d > '${path}.tmp' && mv -f '${path}.tmp' '${path}'`);
}

async function rebuild(){ await shell(`'${MODDIR}/scripts/rebuild-config.sh'`); }

async function loadStatus(){
  try{
    const out = await shell(`'${MODDIR}/scripts/status.sh' 2>/dev/null || true`);
    const [state, engine, pid, ...verParts] = out.trim().split('|');
    const ver = verParts.join('|') || 'unknown';
    $('state').textContent = state === 'running' ? `运行中 · PID ${pid}` : '已停止';
    $('version').textContent = ver.replace(/^threadctl-rs\s*/,'v') || '—';
    $('dot').className = `dot ${state === 'running' ? 'running' : 'stopped'}`;
  }catch(e){
    $('state').textContent = '读取失败'; $('version').textContent='—'; $('dot').className='dot stopped';
  }
}

async function loadManaged(){
  configured.clear();
  const text = await shell(`cat '${MODDIR}/config/apps.tsv' 2>/dev/null || true`);
  for(const line of text.split(/\r?\n/)){
    if(!line || line.startsWith('#')) continue;
    const [pkg, profile] = line.split('\t');
    if(validPkg(pkg) && PROFILES.includes(profile)) configured.set(pkg,profile);
  }
  $('count').textContent = String(configured.size);
  appsDirty=false; $('dirtyApps').textContent='';
}

async function loadAdvanced(){
  advancedOriginal = await shell(`cat '${MODDIR}/config/advanced.kdl' 2>/dev/null || true`);
  $('advanced').value = advancedOriginal;
}

async function packageList(){
  let pkgs=[];
  try{ pkgs=listPackages('user') || []; }catch(_){}
  pkgs = pkgs.map(x => typeof x === 'string' ? x : (x?.packageName || '')).filter(validPkg);
  if(!pkgs.length){
    const out = await shell(`cmd package list packages -3 2>/dev/null || pm list packages -3 2>/dev/null || true`);
    pkgs=out.split(/\r?\n/).map(x=>x.replace(/^package:/,'').trim()).filter(validPkg);
  }
  return [...new Set(pkgs)];
}

async function loadApps(){
  $('loading').hidden=false; $('loading').textContent='正在读取应用列表…'; $('apps').innerHTML='';
  const pkgs=await packageList();
  const info=[];
  for(let i=0;i<pkgs.length;i+=80){
    try{ info.push(...(getPackagesInfo(pkgs.slice(i,i+80)) || [])); }catch(_){}
  }
  const byPkg=new Map();
  for(const x of info) if(x?.packageName) byPkg.set(x.packageName,x);
  appItems=pkgs.map(packageName=>{
    const x=byPkg.get(packageName)||{};
    return {packageName, appLabel:x.appLabel||packageName, versionName:x.versionName||''};
  }).sort((a,b)=>a.appLabel.localeCompare(b.appLabel,'zh-CN'));
  $('loading').hidden=!!appItems.length;
  if(!appItems.length) $('loading').textContent='没有读取到第三方应用。请从 KernelSU 管理器打开本 WebUI。';
  render();
}

function render(){
  const q=$('search').value.trim().toLowerCase();
  const f=$('filter').value;
  const arr=appItems.filter(x=>{
    const has=configured.has(x.packageName);
    if(f==='configured'&&!has) return false;
    if(f==='unconfigured'&&has) return false;
    return !q || x.appLabel.toLowerCase().includes(q) || x.packageName.toLowerCase().includes(q);
  });
  const root=$('apps'); root.innerHTML='';
  if(!arr.length && appItems.length){ const e=document.createElement('div');e.className='empty';e.textContent='没有符合条件的应用。';root.append(e);return; }
  const frag=document.createDocumentFragment();
  for(const item of arr){
    const row=document.createElement('div'); row.className='app';
    const icon=document.createElement('img'); icon.className='icon'; icon.alt=''; icon.src=`ksu://icon/${item.packageName}`; icon.addEventListener('error',()=>icon.style.visibility='hidden',{once:true});
    const text=document.createElement('div');
    const name=document.createElement('div');name.className='name';name.textContent=item.appLabel;
    const pkg=document.createElement('div');pkg.className='pkg';pkg.textContent=item.packageName+(item.versionName?` · ${item.versionName}`:'');text.append(name,pkg);
    const sel=document.createElement('select'); sel.setAttribute('aria-label',`${item.appLabel} 策略`);
    const current=configured.get(item.packageName)||'balanced';
    for(const p of PROFILES){const o=document.createElement('option');o.value=p;o.textContent=p;o.selected=p===current;sel.append(o);}
    sel.disabled=!configured.has(item.packageName);
    sel.addEventListener('change',()=>{if(configured.has(item.packageName)){configured.set(item.packageName,sel.value);markAppsDirty();}});
    const btn=document.createElement('button');btn.className='toggle'+(configured.has(item.packageName)?' added':'');btn.textContent=configured.has(item.packageName)?'移除':'添加';
    btn.addEventListener('click',()=>{
      if(configured.has(item.packageName)){configured.delete(item.packageName);sel.disabled=true;btn.textContent='添加';btn.classList.remove('added');}
      else{configured.set(item.packageName,sel.value);sel.disabled=false;btn.textContent='移除';btn.classList.add('added');}
      markAppsDirty(); if($('filter').value!=='all') render();
    });
    row.append(icon,text,sel,btn);frag.append(row);
  }
  root.append(frag);
}

function markAppsDirty(){ appsDirty=true;$('count').textContent=String(configured.size);$('dirtyApps').textContent='有未保存更改'; }

async function saveManaged(){
  $('saveApps').disabled=true;
  try{
    const entries=[...configured.entries()].filter(([p,r])=>validPkg(p)&&PROFILES.includes(r)).sort((a,b)=>a[0].localeCompare(b[0]));
    const text='# package\tprofile\n'+entries.map(([p,r])=>`${p}\t${r}`).join('\n')+(entries.length?'\n':'');
    await writeText(`${MODDIR}/config/apps.tsv`,text);
    await rebuild();
    appsDirty=false;$('dirtyApps').textContent='已保存；原版 daemon 将热加载';$('count').textContent=String(entries.length);notify('应用策略已保存');
  }catch(e){$('dirtyApps').textContent='保存失败：'+e.message;notify('保存失败');}
  finally{$('saveApps').disabled=false;}
}

async function saveAdvanced(){
  $('saveAdvanced').disabled=true;
  try{
    const text=$('advanced').value;
    await writeText(`${MODDIR}/config/advanced.kdl`,text,true);
    await rebuild(); advancedOriginal=text; notify('高级 KDL 已保存');
  }catch(e){notify('保存失败：'+e.message);}
  finally{$('saveAdvanced').disabled=false;}
}

async function showLog(){
  try{$('output').textContent=(await shell(`tail -n 160 '${MODDIR}/run/threadctl.log' 2>/dev/null || echo '暂无日志'`)).trim()||'暂无日志';}catch(e){$('output').textContent=e.message;}
}
async function showPreview(){
  try{$('output').textContent=await shell(`cat '${MODDIR}/config/threadctl.kdl' 2>/dev/null || echo '配置尚未生成'`);}catch(e){$('output').textContent=e.message;}
}
async function restart(){
  $('restart').disabled=true;
  try{await shell(`'${MODDIR}/scripts/restart.sh'`);notify('原版 daemon 已重启');await loadStatus();await showLog();}catch(e){notify('重启失败：'+e.message);}finally{$('restart').disabled=false;}
}

$('search').addEventListener('input',render);$('filter').addEventListener('change',render);
$('saveApps').addEventListener('click',saveManaged);$('saveAdvanced').addEventListener('click',saveAdvanced);
$('reloadAdvanced').addEventListener('click',loadAdvanced);$('refreshLog').addEventListener('click',showLog);$('preview').addEventListener('click',showPreview);$('restart').addEventListener('click',restart);
$('refresh').addEventListener('click',async()=>{await Promise.all([loadManaged(),loadAdvanced(),loadStatus()]);await loadApps();});
window.addEventListener('beforeunload',e=>{if(appsDirty||$('advanced').value!==advancedOriginal){e.preventDefault();e.returnValue='';}});

(async()=>{
  try{await Promise.all([loadManaged(),loadAdvanced(),loadStatus()]);await loadApps();}
  catch(e){$('loading').hidden=false;$('loading').textContent='初始化失败：'+e.message;}
})();
