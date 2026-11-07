/* Prestador 360 — laboratório fiscal v0.2, 07/11/2026.
 * Simulação matemática de regras legais, NÃO apuração oficial nem NFS-e.
 * Fontes: LC 123/2006; LC 227/2026 anexos XX/XXI; Res. CGSN 140/2018.
 */
(()=>{
"use strict";
const $=s=>document.querySelector(s),fmt=n=>Number(n).toLocaleString("pt-BR",{style:"currency",currency:"BRL"}),percent=n=>(n*100).toLocaleString("pt-BR",{maximumFractionDigits:5})+"%";
const brackets={
  III:[[180000,.06,0],[360000,.112,9360],[720000,.135,17640],[1800000,.16,35640],[3600000,.21,125640]],
  IV:[[180000,.045,0],[360000,.09,8100],[720000,.102,12420],[1800000,.14,39780],[3600000,.22,183780]]
};
const shares={
  "2026III":[[4,3.5,12.82,2.78,43.4,33.5],[4,3.5,14.05,3.05,43.4,32],[4,3.5,13.64,2.96,43.4,32.5],[4,3.5,13.64,2.96,43.4,32.5]],
  "2026IV":[[18.8,15.2,17.67,3.83,44.5],[19.8,15.2,20.55,4.45,40],[20.8,15.2,19.73,4.27,40],[17.8,19.2,18.9,4.1,40]],
  "2027III":[[4,3.5,15.43,43.4,33.5,.17],[4,3.5,16.91,43.4,32,.19],[4,3.5,16.42,43.4,32.5,.19],[4,3.5,16.42,43.4,32.5,.19]],
  "2027IV":[[18.8,15.2,21.26,44.5,.24],[19.8,15.2,24.73,40,.27],[20.8,15.2,23.74,40,.26],[17.8,19.2,22.75,40,.25]]
};
const labels={III:{"2026":["IRPJ","CSLL","Cofins","PIS","CPP","ISS"],"2027":["IRPJ","CSLL","CBS","CPP","ISS","IBS"]},IV:{"2026":["IRPJ","CSLL","Cofins","PIS","ISS"],"2027":["IRPJ","CSLL","CBS","ISS","IBS"]}};
const cents=n=>Math.round((n+Number.EPSILON)*100);
const sum=a=>a.reduce((v,n)=>v+n,0);
const fail=msg=>({ok:false,error:msg});
function calc(x){
 const {year,regime,activity,rbt,monthly,confirmed,startup,retention,regular}=x;
 if(![2026,2027].includes(year))return fail("Competência fora de 2026/2027 ainda não implementada.");
 if(!confirmed)return fail("Confirme o enquadramento tributário antes de simular. O nome comercial do serviço não define sozinho o anexo.");
 if(year===2027&&regular)return fail("Opção pelo regime regular de IBS/CBS ainda não suportada. Não se pode usar as parcelas do DAS como se fossem tributação regular.");
 if(retention)return fail("Situações com retenção ou ISS retido exigem apuração específica.");
 if(!Number.isFinite(monthly)||monthly<0)return fail("Informe receita mensal válida.");
 if(regime==="mei"){
  if(year!==2026)return fail("DAS-MEI de 2027 não confirmado; cálculo indisponível.");
  if(activity==="construction")return fail("Enquadramento MEI para construção requer conferência específica da ocupação permitida.");
  return {ok:true,kind:"MEI",year,dasCents:8605,parts:[{tax:"INSS federal",cents:8105},{tax:"ISS municipal",cents:500}],rate:null,warning:"DAS fixo mensal de MEI prestador exclusivamente de serviços em 2026; depende de opção válida e ocupação permitida. Não é imposto calculado sobre cada orçamento."};
 }
 if(regime!=="simples")return fail("Lucro Presumido/Real ainda sem regras completas: bloqueado.");
 if(startup)return fail("Empresas com menos de 12 meses precisam de RBT12 anualizada: não implementado.");
 if(!Number.isFinite(rbt)||rbt<=0||rbt>3600000)return fail("Informe RBT12 entre R$ 0,01 e R$ 3.600.000,00. Acima disso há efeitos de sublimite/ISS fora do DAS.");
 if(activity==="factor"||activity==="other")return fail("Atividade com Fator R ou classificação não validada. Anexos III/V e atividades especiais exigem regra de enquadramento.");
 const ann=activity==="construction"||activity==="cleaning"?"IV":activity==="maintenance"?"III":null;
 if(!ann)return fail("Classificação do serviço não suportada.");
 const idx=brackets[ann].findIndex(b=>rbt<=b[0]); if(idx<0)return fail("Faixa não encontrada.");
 const [limit,nominal,deduction]=brackets[ann][idx];
 const rate=(rbt*nominal-deduction)/rbt;
 const dasCents=cents(monthly*rate);
 let parts=null, rounding=0;
 if(idx<4){
   const lab=labels[ann][String(year)],weights=shares[year+ann][idx];
   const weightTotal=sum(weights);
   // Repartição oficial arredonda percentuais e pode somar 100,01%; reconciliar ao DAS.
   const raw=weights.map(w=>dasCents*(w/weightTotal));
   const rounded=raw.map(Math.round); rounding=dasCents-sum(rounded);
   if(rounding!==0){const eligible=lab.findIndex(l=>l==="IRPJ");rounded[eligible]+=rounding}
   parts=rounded.map((v,i)=>({tax:lab[i],cents:v,share:weights[i]}));
 }
 return {ok:true,kind:"Simples",year,ann,bracket:idx+1,rbt,monthly,rate,nominal,deduction,dasCents,parts,rounding,
   warning:idx===4?"5ª faixa: não exibimos repartição porque o teto efetivo de ISS exige ajuste. DAS apenas orientativo.":ann==="IV"?"Anexo IV: contribuição previdenciária patronal (CPP) fora do DAS, não calculada.":"ISS mostrado é parcela interna do DAS; não é alíquota municipal aplicada de novo."};
}
function el(k){return document.getElementById(k)}
function read(){return {year:Number(el("year").value),regime:el("regime").value,activity:el("activity").value,rbt:Number(el("rbt").value),monthly:Number(el("monthly").value),confirmed:el("confirmed").checked,startup:el("startup").checked,retention:el("retention").checked,regular:el("regular").checked}}
function render(){
 const x=read(),r=calc(x),result=el("results");
 if(x.regime==="mei")el("rbtWrap").style.opacity=".5";else el("rbtWrap").style.opacity="1";
 el("regularWrap").style.display=x.year===2027?"flex":"none";
 if(!r.ok){result.innerHTML='<div class="blocked"><b>Simulação bloqueada</b><p>'+r.error+'</p></div>';return}
 const parts=r.parts?'<div class="part-grid">'+r.parts.map(p=>'<div class="part"><small>'+p.tax+(p.share!=null?" · "+p.share.toLocaleString("pt-BR")+"% do DAS":"")+'</small><b>'+fmt(p.cents/100)+'</b></div>').join("")+'</div>':'';
 result.innerHTML='<div class="out"><div><small>DAS mensal estimado</small><strong>'+fmt(r.dasCents/100)+'</strong></div><div><small>Alíquota efetiva</small><strong>'+(r.rate===null?"Fixa":percent(r.rate))+'</strong></div><div><small>Enquadramento</small><strong>'+(r.ann?"Anexo "+r.ann+" / "+r.bracket+"ª":"MEI")+'</strong></div></div>'+parts+'<div class="msg"><b>Atenção:</b> '+r.warning+(x.year===2027?" Em 2027, CBS e IBS apresentados são parcelas internas do DAS, não tributos adicionais.":" Em 2026, não adicionamos CBS/IBS de teste ao DAS do Simples.")+'</div>';
}
function tests(){
 const base={year:2026,regime:"simples",activity:"maintenance",rbt:240000,monthly:18000,confirmed:true,startup:false,retention:false,regular:false};
 const all=[
 ["Anexo III RBT12 240 mil, 18 mil de receita → DAS 1.314",calc(base).dasCents===131400],
 ["ISS interno Anexo III 2026 → 420,48",calc(base).parts.find(x=>x.tax==="ISS").cents===42048],
 ["Anexo IV → DAS 1.012,50",calc({...base,activity:"construction"}).dasCents===101250],
 ["2027 CBS e IBS dentro do DAS",(()=>{const x=calc({...base,year:2027});return x.dasCents===131400&&x.parts.find(p=>p.tax==="CBS").cents===22220&&x.parts.find(p=>p.tax==="IBS").cents===250})()],
 ["Repartição não duplica tributos",(()=>{const x=calc({...base,year:2027});return sum(x.parts.map(p=>p.cents))===x.dasCents})()],
 ["MEI 2026 → 86,05",calc({...base,regime:"mei"}).dasCents===8605],
 ["MEI 2027 bloqueado",!calc({...base,year:2027,regime:"mei"}).ok],
 ["Regime regular em 2027 bloqueado",!calc({...base,year:2027,regular:true}).ok],
 ["Atividade fator R bloqueada",!calc({...base,activity:"factor"}).ok],
 ["Retenção bloqueada",!calc({...base,retention:true}).ok],
 ["RBT12 acima de 3,6 mi bloqueada",!calc({...base,rbt:3600000.01}).ok],
 ["Empresa em início de atividade bloqueada",!calc({...base,startup:true}).ok],
 ["Sem confirmação, cálculo bloqueado",!calc({...base,confirmed:false}).ok],
 ["5ª faixa oculta repartição",calc({...base,rbt:2000000}).parts===null],
 ["2027 Anexo IV IBS interno",(()=>{const x=calc({...base,year:2027,activity:"construction"});return x.parts.some(p=>p.tax==="IBS")&&sum(x.parts.map(p=>p.cents))===x.dasCents})()]
 ];
 const n=all.filter(v=>v[1]).length;el("tests").innerHTML='<b>'+n+'/'+all.length+' verificações de regressão passaram</b><details><summary>Ver casos</summary>'+all.map(([name,ok])=>'<p>'+(ok?"✅":"❌")+" "+name+'</p>').join("")+'</details>';
}
document.querySelectorAll("input,select").forEach(e=>e.addEventListener("input",render));el("runTests").addEventListener("click",tests);
el("export").addEventListener("click",()=>{const input=read(),res=calc(input),payload={modulo:"Laboratorio Fiscal 360",versao:"0.2",geradoEm:new Date().toISOString(),aviso:"Simulacao orientativa nao fiscal",entrada:input,resultado:res,referencias:["https://legis.senado.gov.br/norma/40180341/publicacao/40181117","https://legis.senado.gov.br/norma/40180341/publicacao/40181123","https://normas.receita.fazenda.gov.br/sijut2consulta/link.action?idAto=92278"]};const a=document.createElement("a");a.href=URL.createObjectURL(new Blob([JSON.stringify(payload,null,2)],{type:"application/json"}));a.download="prestador360-cenario-fiscal.json";a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)});
render();tests();
})();