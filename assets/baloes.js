/*
  Balões que sobem devagar por todo o site. Clicou (ou tocou), o balão estoura
  e sobe uma palavra: Bênção, Cura, Restauração…
  Fica atrás do topo e dos menus/janelas e na frente do conteúdo; só o balão recebe o clique.
  Não aparece com "reduzir movimento" ligado no aparelho.
*/
(function () {
  if (window.__baloesFonte) return; window.__baloesFonte = true;
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  var CORES = ['#b48cff', '#ff8fb1', '#ffb347', '#7ad4cf', '#8fb8ff', '#f7d26a'];
  var PALAVRAS = ['Bênção', 'Cura', 'Restauração', 'Paz', 'Alegria', 'Graça', 'Fé', 'Esperança', 'Amor',
    'Libertação', 'Provisão', 'Vitória', 'Milagre', 'Salvação', 'Perdão', 'Força', 'Sabedoria', 'Vida',
    'Propósito', 'Família', 'Prosperidade', 'Renovo', 'Unção', 'Transformação'];

  var css = '' +
    '#baloes-fonte{position:fixed;inset:0;z-index:15;pointer-events:none;overflow:hidden}' +
    '#baloes-fonte .bl{position:absolute;bottom:-70px;width:24px;height:30px;pointer-events:auto;cursor:pointer;' +
      'animation:blSobe var(--t,18s) linear var(--d,0s) infinite;-webkit-tap-highlight-color:transparent}' +
    '#baloes-fonte .bl b{position:absolute;inset:0;border-radius:50% 50% 50% 50%/45% 45% 55% 55%;background:var(--c);' +
      'box-shadow:inset -4px -5px 0 rgba(0,0,0,.18),inset 3px 3px 0 rgba(255,255,255,.22);opacity:.8;' +
      'animation:blBalanca 3.4s ease-in-out infinite alternate;transform-origin:50% 140%}' +
    '#baloes-fonte .bl b::before{content:"";position:absolute;left:50%;bottom:-3px;width:6px;height:5px;margin-left:-3px;background:var(--c);' +
      'clip-path:polygon(50% 0,100% 100%,0 100%)}' +
    '#baloes-fonte .bl b::after{content:"";position:absolute;left:50%;top:100%;width:1px;height:28px;margin-top:2px;' +
      'background:linear-gradient(var(--c),transparent);opacity:.7}' +
    '#baloes-fonte .bl::before{content:"";position:absolute;inset:-12px -12px -6px}' +  /* área de toque maior */
    '#baloes-fonte .bl:hover b{opacity:1}' +
    '#baloes-fonte .pedaco{position:absolute;width:6px;height:6px;border-radius:50%;background:var(--c);' +
      'animation:blPedaco .7s cubic-bezier(.2,.7,.3,1) forwards}' +
    '#baloes-fonte .palavra{position:absolute;transform:translate(-50%,-50%);white-space:nowrap;pointer-events:none;' +
      'font-family:"Bricolage Grotesque",system-ui,sans-serif;font-weight:800;font-size:clamp(1.3rem,3.2vw,2rem);letter-spacing:-.01em;' +
      'color:var(--c);text-shadow:0 2px 18px rgba(0,0,0,.65),0 0 2px rgba(0,0,0,.6);animation:blPalavra 2.4s cubic-bezier(.2,.7,.2,1) forwards}' +
    '@keyframes blSobe{0%{transform:translate(0,0)}100%{transform:translate(var(--x,30px),calc(-100vh - 140px))}}' +
    '@keyframes blBalanca{from{transform:rotate(-7deg)}to{transform:rotate(7deg)}}' +
    '@keyframes blPedaco{from{transform:translate(0,0) rotate(0);opacity:1}to{transform:translate(var(--px),var(--py)) rotate(240deg);opacity:0}}' +
    '@keyframes blPalavra{0%{opacity:0;transform:translate(-50%,-50%) scale(.4)}18%{opacity:1;transform:translate(-50%,-70%) scale(1.12)}' +
      '30%{transform:translate(-50%,-75%) scale(1)}80%{opacity:1}100%{opacity:0;transform:translate(-50%,-190%) scale(1)}}' +
    '#baloes-fonte .bl.some{animation-play-state:paused;visibility:hidden}';

  function inicia() {
    var st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
    var palco = document.createElement('div'); palco.id = 'baloes-fonte'; palco.setAttribute('aria-hidden', 'true');
    document.body.appendChild(palco);

    var celular = innerWidth < 700;
    var nBaloes = celular ? 6 : 9;
    var rnd = function (a, b) { return a + Math.random() * (b - a); };
    var cor = function () { return CORES[Math.floor(Math.random() * CORES.length)]; };
    var ultima = '';

    function sorteia(el, primeira) {
      el.style.left = rnd(3, 95).toFixed(1) + '%';
      el.style.setProperty('--c', cor());
      el.style.setProperty('--x', Math.round(rnd(-60, 60)) + 'px');
      var t = rnd(17, 27); el.style.setProperty('--t', t.toFixed(1) + 's');
      el.style.setProperty('--d', (primeira ? -rnd(0, t) : rnd(0, 6)).toFixed(1) + 's');
    }

    function estoura(bl) {
      if (bl.classList.contains('some')) return;
      var r = bl.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
      var c = getComputedStyle(bl).getPropertyValue('--c');
      bl.classList.add('some');
      for (var k = 0; k < 10; k++) {
        var p = document.createElement('i'); p.className = 'pedaco';
        var ang = k / 10 * Math.PI * 2 + rnd(-.3, .3), dist = rnd(30, 60);
        p.style.left = x + 'px'; p.style.top = y + 'px'; p.style.setProperty('--c', c);
        p.style.setProperty('--px', Math.round(Math.cos(ang) * dist) + 'px'); p.style.setProperty('--py', Math.round(Math.sin(ang) * dist) + 'px');
        palco.appendChild(p); setTimeout(p.remove.bind(p), 800);
      }
      var w; do { w = PALAVRAS[Math.floor(Math.random() * PALAVRAS.length)]; } while (w === ultima); ultima = w;
      var pal = document.createElement('span'); pal.className = 'palavra'; pal.textContent = w;
      pal.style.setProperty('--c', c);
      pal.style.left = Math.min(Math.max(x, 90), innerWidth - 90) + 'px'; pal.style.top = Math.max(y, 110) + 'px';
      palco.appendChild(pal); setTimeout(pal.remove.bind(pal), 2500);
      // volta a subir lá de baixo depois de um tempinho
      setTimeout(function () {
        bl.style.animation = 'none'; void bl.offsetWidth; bl.style.animation = '';
        sorteia(bl, false); bl.classList.remove('some');
      }, 2600);
    }

    for (var j = 0; j < nBaloes; j++) {
      var bl = document.createElement('span'); bl.className = 'bl'; bl.innerHTML = '<b></b>';
      sorteia(bl, true);
      bl.addEventListener('animationiteration', function (e) { if (e.target === this) { var b = this; b.style.left = rnd(3, 95).toFixed(1) + '%'; } });
      bl.addEventListener('pointerdown', function (e) { e.preventDefault(); estoura(this); });
      palco.appendChild(bl);
    }
  }

  if (document.body) inicia(); else document.addEventListener('DOMContentLoaded', inicia);
})();
