/*
  Add-on Raumprogramm-Prüfer (Experiment, 18.11.)

  Vergleicht die Räume aus den Grundrissen (Name und Fläche aus den Raumstempeln) mit einem Raumprogramm (PDF).
  - Das Raumprogramm liest pdf.js im Browser (geht auch mit Word- und iPhone-PDFs).
  - Die Grundrisse schickt die Seite an den Server (/raeume): Räume mit Fläche und Geschoss.
  - Zuordnung nach ähnlichen Namen, korrigierbar per Ziehen oder Antippen (Raum-Puzzle).
  - Eine Zeile mit mehreren Räumen ("Windfang / Info / Kasse 40 qm") zählt als Gruppe: alle passenden Räume zusammen.

  Entfernen: in index.html die zwei Zeilen mit raumprogramm.css/.js löschen (oder diese Datei löschen).
  Zurück zum Stand davor: Git-Markierung "vor-raumprogramm".
*/
(() => {
  const pp = window.planpruefer;
  if (!pp) return;
  const el = pp.el;
  const $ = id => document.getElementById(id);
  const de = (z, stellen = 2) => z.toLocaleString('de-DE', { minimumFractionDigits: stellen, maximumFractionDigits: stellen });

  // ---------------------------------------------------------------- Seite und Taskleiste anlegen
  const leiste = $('taskleiste');
  leiste.append(el('span', 'task-pfeil', '›'));
  const gruppe = el('div', 'task-gruppe'); gruppe.id = 'taskRaumprogramm';
  const taskKnopf = el('button', 'task'); taskKnopf.type = 'button'; taskKnopf.title = 'Raumprogramm';
  taskKnopf.append(el('span', 'schritt', '2'), document.createTextNode('Raumprogramm'));
  gruppe.append(taskKnopf); leiste.append(gruppe);

  const seite = el('main', 'seite versteckt'); seite.id = 'seiteRaumprogramm';
  seite.innerHTML = `
  <div class="bento">
    <section class="kachel banner breit rp-banner" aria-label="Raumprogramm-Prüfer">
      <div>
        <h1>RAUM<br>PROGRAMM</h1>
        <p>Passt dein Entwurf zum Raumprogramm? Lade das Raumprogramm und deine Grundrisse hoch. Der Prüfer legt jeden Raum wie ein Puzzleteil an seinen Platz und zeigt dir Soll, Ist und Abweichung.</p>
      </div>
      <svg viewBox="0 0 260 220" aria-hidden="true" class="rp-puzzle">
        <g class="teil t1"><rect x="20" y="40" width="90" height="70" rx="12" fill="#FFFFFF"/><circle cx="110" cy="75" r="14" fill="#FFFFFF"/></g>
        <g class="teil t2"><rect x="124" y="40" width="96" height="70" rx="12" fill="#A7B6D0"/><circle cx="172" cy="110" r="14" fill="#A7B6D0"/></g>
        <g class="teil t3"><rect x="20" y="124" width="90" height="70" rx="12" fill="#A7B6D0"/><circle cx="65" cy="124" r="14" fill="#A7B6D0"/></g>
        <g class="teil t4"><rect x="124" y="124" width="96" height="70" rx="12" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="4" stroke-dasharray="10 8" fill-opacity=".15"/><circle cx="124" cy="159" r="14" fill="#1E2F4F"/></g>
        <g class="teil t5"><rect x="150" y="150" width="96" height="70" rx="12" fill="#FFFFFF"/><circle cx="150" cy="185" r="14" fill="#FFFFFF"/></g>
      </svg>
    </section>

    <div class="frage">Was soll verglichen werden?</div>
    <div class="kachel ablage rp-ablage" id="rpProgrammAblage" role="button" tabindex="0" aria-label="Raumprogramm als PDF auswählen">
      <input type="file" id="rpProgrammDatei" accept="application/pdf,.pdf">
      <div class="rp-nr">1</div>
      <div class="gross rp-gross">Raum&shy;programm</div>
      <div class="leise" id="rpProgrammText">PDF hierher ziehen oder klicken (aus Word, vom iPad, egal).</div>
      <div class="dateien" id="rpProgrammListe"></div>
    </div>
    <div class="kachel ablage rp-ablage" id="rpPlanAblage" role="button" tabindex="0" aria-label="Grundrisse als PDF auswählen">
      <input type="file" id="rpPlanDatei" accept="application/pdf,.pdf" multiple>
      <div class="rp-nr">2</div>
      <div class="gross rp-gross">Grund&shy;risse</div>
      <div class="leise" id="rpPlanText">Alle Geschosse als PDF (meist zwei). Nur Pläne mit Flächen in den Raumstempeln.</div>
      <div class="dateien" id="rpPlanListe"></div>
    </div>
    <div class="kachel breit rp-los">
      <div>
        <div class="rp-los-titel">Bereit für das Puzzle?</div>
        <div class="leise" id="rpLosText">Erst Raumprogramm und Grundrisse hochladen.</div>
      </div>
      <button class="start rp-start" id="rpStart" type="button" disabled title="Raumprogramm prüfen" aria-label="Raumprogramm prüfen">
        <svg class="lupe" viewBox="0 0 32 32" aria-hidden="true"><circle cx="13" cy="13" r="8.5" fill="none" stroke="currentColor" stroke-width="3.5"/><path d="M19.5 19.5 L27 27" stroke="currentColor" stroke-width="4.5" stroke-linecap="round"/></svg>
        <svg class="rp-dreh" viewBox="0 0 82 82" aria-hidden="true"><circle cx="41" cy="41" r="37"/></svg>
      </button>
    </div>
    <div class="status" id="rpStatus" aria-live="polite"></div>
  </div>

  <section class="rp-ergebnis versteckt" id="rpErgebnis" aria-live="polite">
    <div class="kachel rp-kopf">
      <svg class="rp-ring" viewBox="0 0 120 120" aria-hidden="true"><circle class="spur" cx="60" cy="60" r="50"/><circle class="wert" id="rpRingWert" cx="60" cy="60" r="50"/></svg>
      <div class="rp-ring-zahl"><b id="rpTreffer">0/0</b><span>Zeilen belegt</span></div>
      <div class="rp-kopf-text">
        <h2 id="rpTitel">Raumprogramm</h2>
        <div class="rp-summen" id="rpSummen"></div>
        <div class="rp-geschosse" id="rpGeschosse"></div>
      </div>
    </div>
    <p class="rp-tipp">Tipp: Ein Raum liegt falsch? Zieh ihn auf die richtige Karte, oder tippe ihn an und dann auf die Karte. Passt eine Zeile zu einer anderen (zum Beispiel Windfang/Info/Kasse liegt in der Ausstellung)? Zieh die Karte an ihrem Griff ≡ auf die andere, dann zählen beide zusammen. Mit × trennst du sie wieder.</p>
    <div class="rp-karten" id="rpKarten"></div>
    <div class="kachel rp-pool" id="rpPool" data-zeile="pool">
      <div class="rp-pool-kopf"><b>Nicht zugeordnet</b><span class="leise">Räume aus den Plänen, die zu keiner Zeile passen. Hierher ziehen nimmt einen Raum aus der Rechnung.</span></div>
      <div class="rp-chips" id="rpPoolChips"></div>
    </div>
  </section>

  <button class="zurueck" id="rpZurueck" type="button"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 12 H5 M11 5 L4 12 L11 19"/></svg>Zurück zum Planprüfer</button>`;
  // vor das erste Skript im <body> (ein Skript im <head>, etwa der Demo-Baustein der Online-Version, ist kein Platz für eine Seite)
  document.body.insertBefore(seite, document.body.querySelector(':scope > script'));

  // Übergangs-Kachel auf der Ergebnisseite: erscheint, wenn alles abgehakt ist
  const weiter = el('section', 'kachel rp-weiter versteckt');
  weiter.innerHTML = `
    <svg viewBox="0 0 64 64" aria-hidden="true"><rect x="6" y="14" width="24" height="20" rx="5" fill="#FFFFFF"/><circle cx="30" cy="24" r="5" fill="#FFFFFF"/>
      <rect x="34" y="14" width="24" height="20" rx="5" fill="#A7B6D0"/><rect x="6" y="38" width="24" height="20" rx="5" fill="#A7B6D0"/>
      <rect x="34" y="38" width="24" height="20" rx="5" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-dasharray="5 4"/></svg>
    <div><b>Alles abgehakt, stark!</b><span>Lust auf eine Extra-Runde? Prüfe, ob dein Entwurf auch zum Raumprogramm passt.</span></div>`;
  const weiterKnopf = el('button', 'rp-weiter-knopf', 'Zum Raumprogramm-Prüfer →'); weiterKnopf.type = 'button';
  weiter.append(weiterKnopf);
  $('inOrdnung').after(weiter);

  // ---------------------------------------------------------------- Zustand
  let programmDatei = null;
  let planDateien = [];
  let zeilen = [];      // Zeilen des Raumprogramms
  let raeume = [];      // Räume aus den Plänen
  let zuordnung = {};   // Raum-ID -> Zeilen-ID oder 'pool'
  let gewaehlterRaum = null;
  let konfettiSchonGezeigt = false;
  let laeuft = false;
  pp.rpPlaene = () => planDateien;   // für das Add-on GRZ/GFZ: dieselben Grundrisse mitnehmen

  function oeffne() {
    // Pläne aus der Prüfung übernehmen, wenn noch keine gewählt sind
    if (planDateien.length === 0 && pp.ergebnisse.length) planDateien = pp.ergebnisse.map(e => e.datei);
    zeigeUpload();
    pp.zeigeSeite('seiteRaumprogramm');
  }
  taskKnopf.addEventListener('click', oeffne);
  weiterKnopf.addEventListener('click', oeffne);
  $('rpZurueck').addEventListener('click', () => { if (pp.ergebnisse.length) pp.zeigeSeite2(); else pp.zeigeSeite('seite1'); });
  document.addEventListener('planpruefer:seite', ev => { gruppe.classList.toggle('aktiv', ev.detail.id === 'seiteRaumprogramm'); taskKnopf.classList.toggle('an', ev.detail.id === 'seiteRaumprogramm'); });

  // Alle Befunde aller geprüften Pläne erledigt?
  function allesErledigt() {
    const erg = pp.ergebnisse; if (!erg.length) return false;
    return erg.every(e => e.daten.befunde.filter(b => !b.ok).every((b, i) => e.erledigt.has(i + 1)));
  }
  function pruefeWeiter() {
    const vorher = weiter.classList.contains('versteckt');
    const zeigen = allesErledigt();
    weiter.classList.toggle('versteckt', !zeigen);
    if (zeigen && vorher) { weiter.classList.remove('rein'); void weiter.offsetWidth; weiter.classList.add('rein'); }
  }
  document.addEventListener('planpruefer:abgehakt', () => setTimeout(pruefeWeiter, 0));
  document.addEventListener('planpruefer:seite', pruefeWeiter);

  // ---------------------------------------------------------------- Upload
  function ablage(kachelId, inputId, mehrere, aufnehmen) {
    const k = $(kachelId), i = $(inputId);
    k.addEventListener('click', ev => { if (ev.target.closest('.datei-chip')) return; i.click(); });
    k.addEventListener('keydown', ev => { if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); i.click(); } });
    i.addEventListener('change', () => { aufnehmen(Array.from(i.files)); i.value = ''; });
    k.addEventListener('dragover', ev => { ev.preventDefault(); k.classList.add('ueber'); });
    k.addEventListener('dragleave', () => k.classList.remove('ueber'));
    k.addEventListener('drop', ev => { ev.preventDefault(); k.classList.remove('ueber'); aufnehmen(Array.from(ev.dataTransfer.files)); });
  }
  const nurPdf = liste => liste.filter(f => /\.pdf$/i.test(f.name) || f.type === 'application/pdf');
  ablage('rpProgrammAblage', 'rpProgrammDatei', false, liste => { const f = nurPdf(liste)[0]; if (f) programmDatei = f; else if (liste.length) zeigeStatus('Bitte das Raumprogramm als PDF hochladen.', true); zeigeUpload(); });
  ablage('rpPlanAblage', 'rpPlanDatei', true, liste => { for (const f of nurPdf(liste)) if (!planDateien.some(g => g.name === f.name && g.size === f.size)) planDateien.push(f); zeigeUpload(); });

  function chip(name, weg) {
    const c = el('span', 'datei-chip', name);
    const b = el('button', '', '×'); b.type = 'button'; b.title = 'Entfernen'; b.setAttribute('aria-label', name + ' entfernen');
    b.addEventListener('click', ev => { ev.stopPropagation(); weg(); zeigeUpload(); });
    c.append(b); return c;
  }
  function zeigeUpload() {
    const pl = $('rpProgrammListe'); pl.textContent = '';
    if (programmDatei) pl.append(chip(programmDatei.name, () => { programmDatei = null; }));
    const gl = $('rpPlanListe'); gl.textContent = '';
    planDateien.forEach((f, i) => gl.append(chip(f.name, () => { planDateien.splice(i, 1); })));
    $('rpProgrammAblage').classList.toggle('erledigt', !!programmDatei);
    $('rpPlanAblage').classList.toggle('erledigt', planDateien.length > 0);
    $('rpPlanText').textContent = planDateien.length && pp.ergebnisse.length && planDateien.every(f => pp.ergebnisse.some(e => e.datei === f))
      ? 'Aus der Prüfung übernommen. Weitere Geschosse hier dazulegen.'
      : 'Alle Geschosse als PDF (meist zwei). Nur Pläne mit Flächen in den Raumstempeln.';
    const bereit = !!programmDatei && planDateien.length > 0 && !laeuft;
    $('rpStart').disabled = !bereit;
    $('rpLosText').textContent = laeuft ? 'Einen Moment, die Teile werden sortiert …'
      : bereit ? 'Mit der Lupe starten.' : (!programmDatei ? 'Es fehlt noch das Raumprogramm.' : 'Es fehlen noch die Grundrisse.');
  }
  function zeigeStatus(text, fehler) {
    const s = $('rpStatus'); s.textContent = '';
    if (!text) return;
    if (fehler) s.append(el('div', 'meldung-fehler', text)); else s.textContent = text;
  }

  // ---------------------------------------------------------------- Raumprogramm lesen (pdf.js)
  async function leseProgramm(datei) {
    await pp.ladePdfjs();
    const pdf = await window.pdfjsLib.getDocument({ data: await datei.arrayBuffer() }).promise;
    const alleZeilen = [];
    for (let s = 1; s <= pdf.numPages; s++) {
      const seiteP = await pdf.getPage(s);
      const inhalt = await seiteP.getTextContent();
      const stuecke = inhalt.items.filter(i => i.str && i.str.trim()).map(i => ({ t: i.str, x: i.transform[4], y: i.transform[5], b: i.width || (i.str.length * 5) }));
      stuecke.sort((a, b) => b.y - a.y || a.x - b.x);
      const zl = [];
      for (const st of stuecke) {
        const z = zl.find(z => Math.abs(z.y - st.y) <= 3);
        if (z) z.teile.push(st); else zl.push({ y: st.y, teile: [st], seite: s });
      }
      for (const z of zl) {
        z.teile.sort((a, b) => a.x - b.x);
        // Abschnitte: Lücke über 18 Punkt trennt (Spalten der Tabelle)
        const abschnitte = [];
        for (const t of z.teile) {
          const letzter = abschnitte[abschnitte.length - 1];
          if (letzter && t.x - letzter.ende <= 18) { letzter.text += (t.x - letzter.ende > 1.5 ? ' ' : '') + t.t; letzter.ende = Math.max(letzter.ende, t.x + t.b); }
          else abschnitte.push({ text: t.t, x: t.x, ende: t.x + t.b });
        }
        abschnitte.forEach(a => a.text = a.text.replace(/\s+/g, ' ').trim());
        z.abschnitte = abschnitte.filter(a => a.text);
        z.text = z.abschnitte.map(a => a.text).join(' ');
        alleZeilen.push(z);
      }
    }
    return { zeilen: zerlegeProgramm(alleZeilen), text: alleZeilen.map(z => z.text).join('\n'), titel: alleZeilen.find(z => /[A-Za-zÄÖÜ]{4,}/.test(z.text))?.text || 'Raumprogramm' };
  }

  // Fläche wie "40 qm", "65 m²". Für jede Suche ein neues Muster (ein gemeinsames /g-Muster merkt sich die letzte Stelle)
  const FLAECHE_QUELLE = '(\\d{1,5}(?:[.,]\\d{1,2})?)\\s*(?:qm|m²|m2)(?![a-zäöü])';
  const flaechen = text => [...text.matchAll(new RegExp(FLAECHE_QUELLE, 'gi'))];
  function zerlegeProgramm(zl) {
    const mitFlaeche = z => flaechen(z.text).length > 0;
    const istSumme = z => /^\s*(summe|gesamt|insgesamt)\b/i.test(z.text) || /\bsumme\b/i.test(z.abschnitte[0]?.text || '');
    const erste = zl.findIndex(z => mitFlaeche(z) && !istSumme(z));
    if (erste < 0) return [];
    let ende = zl.findIndex((z, i) => i > erste && istSumme(z));
    let summe = null;
    if (ende >= 0) { const m = flaechen(zl[ende].text); if (m.length) summe = zahl(m[m.length - 1][1]); }
    else { ende = zl.length; for (let i = zl.length - 1; i > erste; i--) if (mitFlaeche(zl[i])) { ende = i + 1; break; } }
    const tabelle = zl.slice(erste, ende).filter(z => /[A-Za-zÄÖÜäöüß]{2,}/.test(z.text) && !/^\(/.test(z.text));
    const linkeKante = Math.min(...tabelle.map(z => z.abschnitte[0].x));
    const ergebnis = [];
    let aktGruppe = '';
    tabelle.forEach((z, n) => {
      let teile = z.abschnitte.map(a => ({ ...a }));
      // Fläche heraustrennen (letzte Angabe mit qm/m²)
      let soll = null, sollText = '';
      const alle = flaechen(z.text);
      if (alle.length) {
        soll = zahl(alle[alle.length - 1][1]);
        teile = teile.map(a => ({ ...a, text: a.text.replace(new RegExp(FLAECHE_QUELLE, 'gi'), '').replace(/[→\->]+\s*$/, '').trim() })).filter(a => a.text);
      }
      const ea = teile.findIndex(a => /entwurfsabh/i.test(a.text));
      if (ea >= 0) { sollText = 'entwurfsabhängig'; teile.splice(ea, 1); }
      teile = teile.filter(a => /[A-Za-zÄÖÜäöüß]/.test(a.text));
      if (!teile.length) return;
      let kopf = '';
      if (teile.length >= 2 && Math.abs(teile[0].x - linkeKante) <= 6) { kopf = teile.shift().text; aktGruppe = kopf; }
      else if (teile.length === 1 && Math.abs(teile[0].x - linkeKante) <= 6 && soll === null && !sollText) { aktGruppe = teile[0].text; return; }
      const rest = teile.map(a => a.text).join(' ').replace(/[→]/g, '').trim();
      // Ist der Rest eine Beschreibung ("mit kleiner Anrichte", "Höhe bis 6 m")? Dann ist die linke Spalte der Raum.
      // Sonst sind es Raumnamen ("Vortragsraum") und die linke Spalte ist die Gruppe ("Veranstaltung").
      const beschreibt = /^(mit|ohne|inkl|für|fuer|höhe|hoehe|ca\.?|als|bis|je|davon)\b/i.test(rest) || /^[a-zäöü]/.test(rest);
      const titel = kopf && beschreibt ? kopf : rest;
      const beschreibung = kopf && beschreibt ? rest : '';
      const suchText = kopf ? `${kopf} ${rest}` : rest;
      ergebnis.push({ id: 'z' + n, gruppe: kopf && beschreibt ? '' : (kopf || aktGruppe), titel, beschreibung, soll, sollText, woerter: woerter(suchText) });
    });
    ergebnis.summe = summe;
    return ergebnis;
  }
  const zahl = t => parseFloat(String(t).replace(/\./g, (m, i, s) => (/,/.test(s) ? '' : '.')).replace(',', '.'));

  // ---------------------------------------------------------------- Namen vergleichen
  const STOPP = new Set(['mit', 'und', 'oder', 'bis', 'hoehe', 'zwei', 'drei', 'ebene', 'ebenen', 'treppe', 'kleiner', 'kleine', 'klein', 'grosse', 'grosser', 'ca', 'inkl', 'je', 'fuer', 'anlage', 'bereich', 'raeume', 'raum', 'flaeche', 'qm', 'der', 'die', 'das', 'den', 'mind', 'max', 'etwa', 'neu', 'jeweils', 'pro']);
  const GLEICH = { behw: 'wc', beh: 'wc', behwc: 'wc', behinderten: 'wc', behindertenwc: 'wc', barrierefrei: 'wc', barrierefreies: 'wc', toilette: 'wc', toiletten: 'wc', wcs: 'wc', sanitaer: 'wc',
    anrichte: 'kueche', teekueche: 'kueche', kochen: 'kueche', pantry: 'kueche', ausstellungsraum: 'ausstellung', ausstellungsflaeche: 'ausstellung', foyer: 'eingang', eingangshalle: 'eingang' };
  function normal(t) { return t.toLowerCase().replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/ß/g, 'ss').replace(/[^a-z0-9]/g, ''); }
  function woerter(text) {
    const w = new Set();
    const ganz = normal(text.replace(/\(.*?\)/g, ' '));
    for (const roh of text.split(/[\/,;()+&]|\s+|(?<=[a-zäöüß])-(?=[a-zäöüß])/i)) {
      let n = normal(roh); if (!n || /^\d+$/.test(n)) continue;
      if (GLEICH[n]) n = GLEICH[n];
      if (n.length >= 2 && !STOPP.has(n)) w.add(n);
    }
    if (GLEICH[ganz]) w.add(GLEICH[ganz]);
    return [...w];
  }
  function abstand(a, b) {
    if (Math.abs(a.length - b.length) > 2) return 9;
    const d = Array.from({ length: a.length + 1 }, (_, i) => [i]);
    for (let j = 1; j <= b.length; j++) d[0][j] = j;
    for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++) d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    return d[a.length][b.length];
  }
  function wortWert(a, b) {
    if (a === b) return 100;
    if (a.length >= 4 && b.length >= 4) { const ab = abstand(a, b); if (ab <= 1) return 88; if (ab <= 2 && Math.min(a.length, b.length) >= 8) return 75; }
    if (a.length >= 3 && b.length >= 3 && (a.startsWith(b) || b.startsWith(a))) return 80;
    if (a.length >= 4 && b.length >= 4 && (a.includes(b) || b.includes(a))) return 62;
    return 0;
  }
  function passung(raumName, zeile) {
    const rw = woerter(raumName); if (!rw.length) return 0;
    let best = 0;
    for (const a of rw) for (const b of zeile.woerter) best = Math.max(best, wortWert(a, b));
    return best;
  }
  function ordneZu() {
    zuordnung = {};
    for (const r of raeume) {
      let beste = null, bw = 0;
      for (const z of zeilen) { const w = passung(r.name, z) + (z.soll ? 1 : 0); if (w > bw) { bw = w; beste = z; } }
      zuordnung[r.id] = beste && bw >= 60 ? beste.id : 'pool';
    }
  }

  // ---------------------------------------------------------------- Prüfen
  $('rpStart').addEventListener('click', async () => {
    if (laeuft || !programmDatei || !planDateien.length) return;
    laeuft = true; $('rpStart').classList.add('laeuft'); zeigeUpload(); zeigeStatus('');
    try {
      zeigeStatus('Lese das Raumprogramm …');
      const prog = await leseProgramm(programmDatei);
      if (!prog.zeilen.length) throw new Error('Im Raumprogramm wurden keine Flächenangaben gefunden (gesucht: Zahlen mit "qm" oder "m²"). Ist es eine eingescannte Seite? Dann geht es leider nicht.');
      zeilen = prog.zeilen;
      raeume = []; const geschosse = []; const ohneGeschoss = [];
      for (let i = 0; i < planDateien.length; i++) {
        const f = planDateien[i];
        zeigeStatus(`Lese Räume aus ${planDateien.length > 1 ? `Grundriss ${i + 1} von ${planDateien.length}: ` : ''}${f.name} …`);
        const r = await fetch('raeume', { method: 'POST', headers: { 'X-Dateiname': encodeURIComponent(f.name) }, body: f });
        const d = await r.json().catch(() => ({ fehler: 'Antwort des Servers nicht lesbar' }));
        if (!r.ok) throw new Error(`${f.name}: ${d.fehler || 'Fehler beim Lesen'}${r.status === 404 ? ' (Server bitte neu starten, damit das Add-on läuft)' : ''}`);
        if (!d.geschosse || !d.geschosse.length) ohneGeschoss.push(f.name);
        (d.geschosse || []).forEach(g => { if (!geschosse.includes(g)) geschosse.push(g); });
        (d.raeume || []).forEach((rm, k) => raeume.push({ id: `r${i}_${k}`, name: rm.name || '(ohne Namen)', flaeche: rm.flaeche, text: rm.text, geschoss: rm.geschoss || (d.geschosse && d.geschosse[0]) || kurzName(f.name), datei: f.name }));
      }
      if (!raeume.length) throw new Error('In den Grundrissen wurden keine Raumflächen gefunden. Das Add-on braucht Raumstempel mit Fläche (zum Beispiel "NGF: 22,50 m²").');
      ordneZu();
      zusammen = {}; gewaehlteZeile = null; gewaehlterRaum = null;
      konfettiSchonGezeigt = false;
      zeigeErgebnis(prog, geschosse, ohneGeschoss);
      zeigeStatus('');
    } catch (e) {
      const grund = e instanceof TypeError && /fetch/i.test(e.message) ? 'Der Planprüfer-Server ist nicht erreichbar.' : e.message;
      zeigeStatus(grund, true);
    } finally {
      laeuft = false; $('rpStart').classList.remove('laeuft'); zeigeUpload();
    }
  });
  const kurzName = n => n.replace(/\.pdf$/i, '');

  // ---------------------------------------------------------------- Ergebnis: Raum-Puzzle
  let letztesProgramm = null, letzteGeschosse = [], letzteOhne = [];
  function zeigeErgebnis(prog, geschosse, ohneGeschoss) {
    letztesProgramm = prog; letzteGeschosse = geschosse; letzteOhne = ohneGeschoss;
    $('rpErgebnis').classList.remove('versteckt');
    $('rpTitel').textContent = prog.titel;
    // Geschosse: erkannt und erwartet
    const g = $('rpGeschosse'); g.textContent = '';
    const erwartet = /(zwei|2|mehrere|beiden)\s*(ebenen|geschosse|etagen)|zweigeschossig|obergeschoss|galerie|empore/i.test(prog.text) ? 2 : 1;
    const anzahl = Math.max(geschosse.length, new Set(raeume.map(r => r.geschoss)).size);
    (geschosse.length ? geschosse : [...new Set(raeume.map(r => r.geschoss))]).forEach(n => g.append(el('span', 'rp-geschoss', n)));
    if (anzahl < erwartet) g.append(el('span', 'rp-warnung', `Das Raumprogramm spricht von mehreren Ebenen, erkannt ${anzahl === 1 ? 'wurde nur ein Geschoss' : `wurden ${anzahl} Geschosse`}. Fehlt ein Grundriss?`));
    if (ohneGeschoss.length) g.append(el('span', 'rp-warnung leicht', `Ohne Geschoss-Beschriftung: ${ohneGeschoss.join(', ')}`));
    zeichneKarten(true);
    $('rpErgebnis').scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  function stufe(p) { const a = Math.abs(p); return a <= 10 ? 'gut' : a <= 25 ? 'mittel' : 'stark'; }

  // Zusammengelegte Zeilen: Passen die Überschriften des Raumprogramms nicht zum Entwurf (zum Beispiel Windfang/Info/Kasse
  // liegt in der Ausstellung), kann man eine Karte auf eine andere ziehen. Dann zählen Soll und Räume beider zusammen.
  let zusammen = {};           // Zeilen-ID -> Zeilen-ID, in die sie gelegt wurde
  let gewaehlteZeile = null;
  const wurzel = id => { let i = id, n = 0; while (zusammen[i] && n++ < 50) i = zusammen[i]; return i; };
  const mitglieder = z => zeilen.filter(x => wurzel(x.id) === z.id);

  function zeichneKarten(mitAnimation) {
    const karten = $('rpKarten'); karten.textContent = '';
    let belegt = 0, sollSumme = 0, istSumme = 0;
    const sichtbar = zeilen.filter(z => !zusammen[z.id]);
    sichtbar.forEach((z, n) => {
      const teile = mitglieder(z); const ids = new Set(teile.map(t => t.id));
      const drin = raeume.filter(r => ids.has(zuordnung[r.id]));
      const istWert = drin.reduce((s, r) => s + r.flaeche, 0);
      const mitSoll = teile.filter(t => t.soll);
      const sollWert = mitSoll.length ? mitSoll.reduce((s, t) => s + t.soll, 0) : null;
      const sollText = sollWert ? '' : (teile.find(t => t.sollText)?.sollText || '');
      if (drin.length) belegt++;
      if (sollWert) { sollSumme += sollWert; istSumme += istWert; }
      const k = el('article', 'kachel rp-karte'); k.dataset.zeile = z.id;
      if (mitAnimation) k.style.animationDelay = (n * 60) + 'ms'; else k.classList.add('still');
      if (!drin.length) k.classList.add('leer');
      if (gewaehlteZeile === z.id) k.classList.add('zeile-gewaehlt');
      const kopf = el('div', 'rp-karte-kopf');
      // Griff: die ganze Zeile auf eine andere Karte ziehen (oder antippen, dann die Zielkarte antippen)
      const griff = el('button', 'rp-griff'); griff.type = 'button'; griff.draggable = true;
      griff.title = 'Diese Zeile auf eine andere Karte ziehen, um beide zusammenzulegen (oder antippen, dann die Zielkarte antippen)';
      griff.setAttribute('aria-label', `${z.titel} mit einer anderen Zeile zusammenlegen`);
      griff.append(el('span'), el('span'), el('span'));
      griff.addEventListener('dragstart', ev => { ev.dataTransfer.setData('text/plain', 'zeile:' + z.id); ev.dataTransfer.effectAllowed = 'move'; k.classList.add('zieht'); });
      griff.addEventListener('dragend', () => k.classList.remove('zieht'));
      griff.addEventListener('click', ev => { ev.stopPropagation(); gewaehlterRaum = null; gewaehlteZeile = gewaehlteZeile === z.id ? null : z.id; document.body.classList.toggle('rp-waehlt', !!gewaehlteZeile); zeichneKarten(false); });
      const namen = el('div', 'rp-namen');
      if (z.gruppe) namen.append(el('small', 'rp-gruppe', z.gruppe));
      namen.append(el('b', 'rp-zeilen-titel', z.titel));
      if (z.beschreibung) namen.append(el('small', 'rp-beschreibung', z.beschreibung));
      const dazu = teile.filter(t => t.id !== z.id);
      if (dazu.length) {
        const liste = el('div', 'rp-dazu-liste');
        dazu.forEach(t => {
          const tag = el('span', 'rp-dazu'); tag.append(document.createTextNode('+ ' + t.titel + (t.soll ? ` (${de(t.soll, 0)} m²)` : '')));
          const weg = el('button', '', '×'); weg.type = 'button'; weg.title = 'Wieder trennen'; weg.setAttribute('aria-label', t.titel + ' wieder trennen');
          weg.addEventListener('click', ev => { ev.stopPropagation(); trenne(t.id); });
          tag.append(weg); liste.append(tag);
        });
        namen.append(liste);
      }
      const soll = el('div', 'rp-soll');
      soll.append(el('small', '', 'Soll'), el('b', '', sollWert ? `${de(sollWert, 0)} m²` : (sollText || 'ohne Fläche')));
      kopf.append(griff, namen, soll); k.append(kopf);

      if (sollWert) {
        const p = (istWert - sollWert) / sollWert * 100;
        const max = Math.max(sollWert, istWert) * 1.1;
        const balken = el('div', 'rp-balken ' + (drin.length ? stufe(p) : 'fehlt'));
        const fuell = el('div', 'rp-fuell'); const marke = el('div', 'rp-marke'); marke.title = `Soll ${de(sollWert, 0)} m²`;
        marke.style.left = (sollWert / max * 100) + '%';
        balken.append(fuell, marke); k.append(balken);
        // kurz warten, dann füllen (so läuft die Füll-Animation; requestAnimationFrame wird in manchen Ansichten nicht ausgelöst)
        const breite = (istWert / max * 100) + '%';
        if (mitAnimation) setTimeout(() => { fuell.style.width = breite; }, 40 + n * 60); else fuell.style.width = breite;
        const zahlen = el('div', 'rp-zahlen');
        zahlen.append(el('span', '', `Ist ${drin.length ? de(istWert) + ' m²' : '–'}`));
        const abw = el('span', 'rp-abw ' + (drin.length ? stufe(p) : 'fehlt'), drin.length ? `${istWert - sollWert >= 0 ? '+' : '−'}${de(Math.abs(istWert - sollWert))} m² · ${p >= 0 ? '+' : '−'}${de(Math.abs(p), 1)} %` : 'fehlt im Plan');
        zahlen.append(abw); k.append(zahlen);
      } else {
        const zahlen = el('div', 'rp-zahlen');
        zahlen.append(el('span', '', drin.length ? `Ist ${de(istWert)} m²` : 'Ist –'), el('span', 'rp-abw ' + (drin.length ? 'gut' : 'fehlt'), drin.length ? 'vorhanden ✓' : 'nicht gefunden'));
        k.append(zahlen);
      }
      const chips = el('div', 'rp-chips'); drin.forEach(r => chips.append(raumChip(r)));
      if (!drin.length) chips.append(el('span', 'rp-leer-text', 'Hier fehlt noch ein Puzzleteil'));
      k.append(chips);
      macheZiel(k, z.id);
      karten.append(k);
    });
    // Nicht zugeordnet
    const pool = $('rpPoolChips'); pool.textContent = '';
    const frei = raeume.filter(r => zuordnung[r.id] === 'pool');
    frei.forEach(r => pool.append(raumChip(r)));
    if (!frei.length) pool.append(el('span', 'rp-leer-text', 'Alle Räume haben ihren Platz gefunden.'));
    macheZiel($('rpPool'), 'pool');
    // Kopf: Ring und Summen
    $('rpTreffer').textContent = `${belegt}/${sichtbar.length}`;
    const u = 2 * Math.PI * 50, ring = $('rpRingWert');
    ring.style.strokeDasharray = u; ring.style.strokeDashoffset = u * (1 - (sichtbar.length ? belegt / sichtbar.length : 0));
    const s = $('rpSummen'); s.textContent = '';
    const sollGes = zeilen.summe || sollSumme;
    const pges = sollGes ? (istSumme - sollGes) / sollGes * 100 : 0;
    s.append(summe('Soll', `${de(sollGes, 0)} m²`, zeilen.summe ? 'laut Raumprogramm' : 'Summe der Zeilen'), summe('Ist', `${de(istSumme)} m²`, 'Räume in Zeilen mit Soll-Fläche'),
      summe('Abweichung', `${istSumme - sollGes >= 0 ? '+' : '−'}${de(Math.abs(istSumme - sollGes), 0)} m² · ${pges >= 0 ? '+' : '−'}${de(Math.abs(pges), 1)} %`, 'Ist gegen Soll', stufe(pges)));
    if (belegt === sichtbar.length && sichtbar.length && !konfettiSchonGezeigt) { konfettiSchonGezeigt = true; konfetti(); }
  }
  function summe(titel, wert, klein, cls) { const d = el('div', 'rp-summe ' + (cls || '')); d.append(el('small', '', titel), el('b', '', wert), el('span', '', klein)); return d; }

  function raumChip(r) {
    const c = el('button', 'rp-chip'); c.type = 'button'; c.draggable = true; c.dataset.raum = r.id;
    c.append(el('b', '', r.name), el('span', '', `${de(r.flaeche)} m²`));
    if (new Set(raeume.map(x => x.geschoss)).size > 1 || letzteGeschosse.length > 1) c.append(el('em', '', kurzGeschoss(r.geschoss)));
    c.title = `${r.name}, ${de(r.flaeche)} m², ${r.geschoss} (${r.datei}). Ziehen oder antippen, um ihn einer anderen Zeile zuzuordnen.`;
    if (gewaehlterRaum === r.id) c.classList.add('gewaehlt');
    c.addEventListener('dragstart', ev => { ev.stopPropagation(); ev.dataTransfer.setData('text/plain', 'raum:' + r.id); ev.dataTransfer.effectAllowed = 'move'; c.classList.add('zieht'); document.body.classList.add('rp-ziehen'); });
    c.addEventListener('dragend', () => { c.classList.remove('zieht'); document.body.classList.remove('rp-ziehen'); });
    c.addEventListener('click', ev => { ev.stopPropagation(); gewaehlteZeile = null; gewaehlterRaum = gewaehlterRaum === r.id ? null : r.id; document.body.classList.toggle('rp-waehlt', !!gewaehlterRaum); zeichneKarten(false); });
    return c;
  }
  function kurzGeschoss(g) { return ({ Erdgeschoss: 'EG', Obergeschoss: 'OG', Untergeschoss: 'UG', Dachgeschoss: 'DG', Galerie: 'Gal.' })[g] || (g || '').replace(/^(\d)\. Obergeschoss$/, '$1.OG'); }
  function aufleuchten(id) { const k = document.querySelector(`[data-zeile="${id}"]`); if (k) { k.classList.remove('passt'); void k.offsetWidth; k.classList.add('passt'); } }
  function verschiebe(raumId, ziel) {
    if (!raumId || !(raumId in zuordnung)) return;
    zuordnung[raumId] = ziel === 'pool' ? 'pool' : wurzel(ziel); gewaehlterRaum = null; document.body.classList.remove('rp-waehlt');
    zeichneKarten(false); aufleuchten(ziel === 'pool' ? 'pool' : wurzel(ziel));
  }
  function legeZusammen(quelle, ziel) {
    gewaehlteZeile = null; document.body.classList.remove('rp-waehlt');
    const q = wurzel(quelle), t = wurzel(ziel);
    if (ziel === 'pool' || q === t) { zeichneKarten(false); return; }
    zusammen[q] = t;
    zeichneKarten(false); aufleuchten(t);
  }
  function trenne(id) { delete zusammen[id]; zeichneKarten(false); aufleuchten(id); }
  function macheZiel(k, zielId) {
    if (k.dataset.zielGebunden) return; k.dataset.zielGebunden = '1';
    k.addEventListener('dragover', ev => { ev.preventDefault(); ev.dataTransfer.dropEffect = 'move'; k.classList.add('ueber'); });
    k.addEventListener('dragleave', ev => { if (!k.contains(ev.relatedTarget)) k.classList.remove('ueber'); });
    k.addEventListener('drop', ev => {
      ev.preventDefault(); k.classList.remove('ueber');
      const d = ev.dataTransfer.getData('text/plain') || '';
      if (d.startsWith('zeile:')) legeZusammen(d.slice(6), zielId);
      else verschiebe(d.replace(/^raum:/, ''), zielId);
    });
    k.addEventListener('click', () => { if (gewaehlterRaum) verschiebe(gewaehlterRaum, zielId); else if (gewaehlteZeile) legeZusammen(gewaehlteZeile, zielId); });
  }
  // Konfetti, wenn jede Zeile mindestens einen Raum hat
  function konfetti() {
    const farben = ['#FFFFFF', '#A7B6D0', '#6F86B0', '#2b4170', '#DCE3EF'];
    const box = el('div', 'rp-konfetti');
    for (let i = 0; i < 90; i++) {
      const s = el('span');
      s.style.left = Math.random() * 100 + 'vw'; s.style.background = farben[i % farben.length];
      s.style.animationDelay = Math.random() * 0.6 + 's'; s.style.animationDuration = 1.8 + Math.random() * 1.4 + 's';
      s.style.setProperty('--dreh', (Math.random() * 720 - 360) + 'deg'); s.style.setProperty('--seit', (Math.random() * 160 - 80) + 'px');
      if (i % 3 === 0) s.style.borderRadius = '50%';
      box.append(s);
    }
    document.body.append(box);
    setTimeout(() => box.remove(), 4000);
  }

  // Für Tests und Vorführungen
  window.raumprogramm = { setzeProgramm: f => { programmDatei = f; zeigeUpload(); }, setzePlaene: l => { planDateien = l.slice(); zeigeUpload(); }, oeffne,
    starte: () => $('rpStart').click(), get zeilen() { return zeilen; }, get raeume() { return raeume; }, get zuordnung() { return zuordnung; }, verschiebe, legeZusammen, trenne, get zusammen() { return zusammen; } };
})();
