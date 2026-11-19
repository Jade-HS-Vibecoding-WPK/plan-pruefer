/*
  Online-Demo des Planprüfers (GitHub Pages)

  Der Planprüfer braucht zum Prüfen seinen PowerShell-Server (pruefung/server.ps1). Den gibt es auf GitHub Pages nicht,
  dort liegen nur feste Dateien. Diese Datei wird NUR in die Online-Version eingebunden (siehe .github/workflows/pages.yml)
  und macht daraus eine Demo:
    - Sie beantwortet die Anfragen der Seite an den Server mit vorher aufgezeichneten, echten Ergebnissen
      (demo/antworten.json, aufgezeichnet mit dem lokalen Server am 19.11.2026).
    - Sie zeigt auf jeder Seite Knöpfe, mit denen man die Beispielpläne lädt und prüft.
    - Eigene Pläne werden nicht geprüft. Die Seite sagt dann freundlich, dass das nur mit dem Programm auf dem
      eigenen Rechner geht. Die KI ist in der Demo aus.

  Der GRZ-Prüfer rechnet ohnehin im Browser: Der Weg "Manuell eingeben" funktioniert online vollständig.
  Lokal (Planpruefer-starten.cmd) wird diese Datei nicht geladen, dort ändert sich nichts.
*/
(() => {
  const BASIS = new URL('./', document.currentScript.src).href;   // .../demo/
  const ANTWORTEN = fetch(BASIS + 'antworten.json').then(r => r.json()).catch(() => ({}));
  const echtesFetch = window.fetch.bind(window);
  const WEGE = ['pruefen', 'raeume', 'grz-grundriss', 'bild', 'ki-test', 'status'];
  const NUR_BEISPIELE = 'In der Online-Demo lassen sich nur die Beispielpläne prüfen (Knöpfe oben auf der Seite). Eigene Pläne prüft der Planprüfer auf dem eigenen Rechner (Planpruefer-starten.cmd).';
  const KI_AUS = 'In der Online-Demo ist die KI ausgeschaltet. Mit dem eigenen Gemini-Schlüssel geht sie im Planprüfer auf dem eigenen Rechner.';

  // ---------------------------------------------------------------- Anfragen an den Server beantworten
  const alsAntwort = (obj, status = 200) => new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json; charset=utf-8' } });
  const warte = ms => new Promise(r => setTimeout(r, ms));
  window.fetch = async (eingabe, init) => {
    const url = new URL(typeof eingabe === 'string' ? eingabe : eingabe.url, location.href);
    const weg = url.pathname.split('/').pop();
    if (url.origin !== location.origin || !WEGE.includes(weg) || url.pathname.includes('/demo/')) return echtesFetch(eingabe, init);
    const kopf = new Headers((init && init.headers) || {});
    const name = decodeURIComponent(kopf.get('X-Dateiname') || '');
    const daten = await ANTWORTEN;
    await warte(500);   // wie eine kurze Prüfung
    if (weg === 'status') return alsAntwort({ ki: false, demo: true });
    if (weg === 'bild') return alsAntwort({ id: '0'.repeat(32) });
    if (weg === 'ki-test') return alsAntwort({ ok: false, fehler: KI_AUS });
    if (weg === 'pruefen') {
      const phase = (kopf.get('X-Phase') || '').toLowerCase();
      const treffer = daten[`pruefen|${name}|${phase}`];
      if (!treffer) {
        const andere = Object.keys(daten).some(k => k.startsWith(`pruefen|${name}|`));
        return alsAntwort({ fehler: andere ? 'Diesen Beispielplan gibt es in der Demo nur für die Werkplanung.' : NUR_BEISPIELE }, 400);
      }
      const kopie = JSON.parse(JSON.stringify(treffer));
      if ((kopf.get('X-Ki') || '').toLowerCase() === 'ja') kopie.meldungen = [...(kopie.meldungen || []), KI_AUS];
      return alsAntwort(kopie);
    }
    const treffer = daten[`${weg}|${name}|`];
    return treffer ? alsAntwort(treffer) : alsAntwort({ fehler: NUR_BEISPIELE }, 400);
  };

  // ---------------------------------------------------------------- Beispielpläne laden
  const datei = async n => new File([await (await echtesFetch(BASIS + n)).blob()], n, { type: 'application/pdf' });
  function setzeDateien(input, dateien) {
    const dt = new DataTransfer(); dateien.forEach(f => dt.items.add(f));
    input.files = dt.files; input.dispatchEvent(new Event('change', { bubbles: true }));
  }
  // Bisher gewählte Dateien entfernen (über die ×-Knöpfe der Datei-Chips, wie eine Nutzerin es täte)
  function leereListe(selektor) {
    for (let i = 0; i < 20; i++) { const b = document.querySelector(`${selektor} .datei-chip button`); if (!b) break; b.click(); }
  }
  const $ = id => document.getElementById(id);
  function tippe(id, wert) { const e = $(id); e.value = wert; e.dispatchEvent(new Event('input', { bubbles: true })); e.dispatchEvent(new Event('change', { bubbles: true })); }

  function kachel(titel, text, knoepfe) {
    const k = document.createElement('section'); k.className = 'kachel breit demo-kachel';
    const kopf = document.createElement('div'); kopf.className = 'demo-kopf';
    const b = document.createElement('b'); b.textContent = titel;
    const s = document.createElement('span'); s.textContent = text;
    kopf.append(b, s); k.append(kopf);
    for (const [label, aktion, hell] of knoepfe) {
      const knopf = document.createElement('button'); knopf.type = 'button'; knopf.className = 'demo-knopf' + (hell ? ' hell' : ''); knopf.textContent = label;
      knopf.addEventListener('click', async () => {
        knopf.disabled = true;
        try { await aktion(); } catch (e) { alert('Das Beispiel konnte nicht geladen werden: ' + e.message); }
        finally { knopf.disabled = false; }
      });
      k.append(knopf);
    }
    return k;
  }
  function nachDemBanner(bento, el) { const banner = bento && bento.querySelector('.banner'); if (banner) banner.after(el); else if (bento) bento.prepend(el); }

  async function planpruefer(name) {
    const pp = window.planpruefer;
    const r = document.querySelector('input[name=phase][value=werk]');
    if (!r.checked) { r.checked = true; r.dispatchEvent(new Event('change', { bubbles: true })); }
    const ki = $('kiAn'); if (ki && ki.checked) ki.click();
    leereListe('#dateiListe');
    pp.fuegeHinzu([await datei(name)]);
    await pp.pruefeAlle();
  }
  async function raumprogramm() {
    leereListe('#rpProgrammListe'); leereListe('#rpPlanListe');
    setzeDateien($('rpProgrammDatei'), [await datei('raumprogramm.pdf')]);
    setzeDateien($('rpPlanDatei'), [await datei('grundriss-eg.pdf'), await datei('grundriss-og.pdf')]);
    $('rpStart').click();
  }
  async function grz() {
    if ($('gzErgebnis') && !$('gzErgebnis').classList.contains('versteckt')) $('gzZurueck').click();   // zurück zur Eingabe
    tippe('gzGrund', '600'); tippe('gzGrz', '0,4');
    $('gzFassung').value = '1990'; $('gzFassung').dispatchEvent(new Event('change', { bubbles: true }));
    const plan = $('gzWegPlan'); if (!plan.checked) { plan.checked = true; plan.dispatchEvent(new Event('change', { bubbles: true })); }
    leereListe('#gzListe');
    setzeDateien($('gzDatei'), [await datei('lageplan.pdf'), await datei('grundriss-eg.pdf'), await datei('grundriss-og.pdf')]);
    $('gzStart').click();
  }
  function grzManuell() {
    tippe('gzGrund', '600'); tippe('gzGrz', '0,4');
    $('gzFassung').value = '1990'; $('gzFassung').dispatchEvent(new Event('change', { bubbles: true }));
    const hand = $('gzWegHand'); if (!hand.checked) { hand.checked = true; hand.dispatchEvent(new Event('change', { bubbles: true })); }
    $('gzManuell').scrollIntoView({ behavior: 'smooth', block: 'center' });
    $('gzMGeb').focus();
  }

  // ---------------------------------------------------------------- Aussehen und Einbau
  const stil = document.createElement('style');
  stil.textContent = `
    .demo-leiste { background: #A7B6D0; color: #0F1E3A; text-align: center; font-size: 13px; font-weight: 600; padding: 6px 14px; line-height: 1.4; }
    .demo-kachel { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; border: 2px dashed #A7B6D0; }
    .demo-kopf { flex: 1 1 100%; display: flex; flex-direction: column; gap: 2px; }
    .demo-kopf b { font-size: 17px; }
    .demo-kopf span { color: #A7B6D0; font-size: 14px; }
    .demo-knopf { border: 0; border-radius: 999px; background: #FFFFFF; color: #0F1E3A; font: inherit; font-weight: 700; padding: 10px 18px; cursor: pointer; }
    .demo-knopf.hell { background: transparent; color: #FFFFFF; border: 1px solid #A7B6D0; }
    .demo-knopf:disabled { opacity: .5; cursor: wait; }
    @media (max-width: 640px) { .demo-knopf { flex: 1 1 100%; } }`;
  document.head.append(stil);

  window.addEventListener('load', () => {
    const leiste = document.createElement('div'); leiste.className = 'demo-leiste';
    leiste.textContent = 'Online-Demo: Ausprobieren mit Beispielplänen. Eigene Pläne prüft der Planprüfer auf dem eigenen Rechner.';
    const nav = document.querySelector('.taskleiste'); if (nav) nav.after(leiste); else document.body.prepend(leiste);

    nachDemBanner(document.querySelector('#seite1 .bento'), kachel('Beispiel ausprobieren', 'Lade einen echten Werkplan aus dem Projekt und sieh dir das Prüfergebnis an.', [
      ['Werkplan mit Fehler (eine BRH fehlt)', () => planpruefer('werkplan-mit-fehler.pdf')],
      ['Werkplan ohne Fehler', () => planpruefer('grundriss-eg.pdf'), true]
    ]));
    nachDemBanner(document.querySelector('#seiteRaumprogramm .bento'), kachel('Beispiel ausprobieren', 'Raumprogramm und die Grundrisse Erdgeschoss und Obergeschoss eines Einfamilienhauses.', [
      ['Beispiel laden und prüfen', raumprogramm]
    ]));
    nachDemBanner($('gzEingabe'), kachel('Beispiel ausprobieren', 'Grundstück 600 m², GRZ 0,4, BauNVO 1990, mit Lageplan und Grundrissen. Oder trag eigene Zahlen von Hand ein, das funktioniert online vollständig.', [
      ['Beispiel mit Lageplan prüfen', grz],
      ['Eigene Zahlen eingeben', grzManuell, true]
    ]));
  });
})();
