/*
  Add-on GRZ-Prüfer (Experiment, 19.11.)

  Prüft, ob ein Entwurf die Grundflächenzahl (GRZ) des Bebauungsplans einhält. Nur GRZ, bundesweit (BauNVO), keine Online-Abfrage.
  - Eingabe von Hand: Grundstücksgröße, GRZ, Jahr des Bebauungsplans (oder die BauNVO-Fassung direkt wählen), Baugebiet.
  - Grundrisse (PDF) liefern Geschosse und Raumflächen (Server: /grz-grundriss). Die Außenmaße sind Schätzungen und bleiben änderbar.
  - Gerechnet wird hier im Browser nach der Arbeitshilfe GRZ/GFZ (Ordner grz-gfz/): Regeln je BauNVO-Fassung 1962, 1968/1977, 1990.
  - GRZ I (Hauptanlagen) und GRZ II (mit den Anlagen, die erst die GRZ II mitzählt) getrennt: bebaut, zulässig, noch frei in m².

  Der Rechenkern (rechne, klassiere) hängt an window.grzRechnen / window.grzKlassiere und ist mit den Beispielen der Arbeitshilfe geprüft.

  Entfernen: in index.html die zwei Zeilen mit grz.css/.js löschen (oder diese Datei löschen).
  Zurück zum Stand davor: Git-Markierung "vor-grz-gfz".
*/
(() => {
  // ================================================================ Rechenkern (ohne Seite)
  const EPS = 1e-6;
  const FASSUNG_NAME = { 1962: 'BauNVO 1962', 1968: 'BauNVO 1968/1977', 1990: 'BauNVO 1990' };
  const fassungAusJahr = j => !j || j < 1962 ? 0 : j <= 1967 ? 1962 : j <= 1989 ? 1968 : 1990;

  // Raumname -> Art der Fläche (Gebäude, Terrasse/Balkon, Garage, Nebenanlage, Tiefgarage)
  function klassiere(name) {
    const n = String(name || '').toLowerCase();
    if (/tiefgarage|tiefgaragen/.test(n)) return 'tiefgarage';
    if (/terrasse|balkon|loggia|freisitz|dachterrasse/.test(n)) return 'terrasse';
    if (/garage|carport|stellplatz|stellpl/.test(n)) return 'garage';
    if (/gartenhaus|gartenh[uü]tte|gartenlaube|ger[aä]teschuppen|schuppen|gew[aä]chshaus|m[uü]llplatz|m[uü]llbox|sauna|pool|schwimm|fahrradst[aä]nder|fahrradabstell|nebengeb/.test(n)) return 'nebenanlage';
    return 'gebaeude';
  }

  // GRZ I = Hauptanlagen, GRZ II = GRZ I plus die Flächen, die erst die GRZ II mitzählt. Beides mit eigener Grenze.
  function rechne(e) {
    const G = e.G;
    if (!(G > 0) || !e.fassung) return null;
    const hinweise = [];
    const ober = (e.floors || []).filter(f => f.oberirdisch !== false);
    const gebaeude = ober.reduce((m, f) => Math.max(m, +f.aussen || 0), 0);
    const kern = e.gebiet === 'kern';
    const T = +e.terrassen || 0, Ga = +e.garagen || 0, Zu = +e.zufahrten || 0, Ne = +e.nebenanlagen || 0, Ti = +e.tiefgarage || 0, Ue = +e.ueberlagerung || 0;
    const grzW = e.grz > 0 ? e.grz : 0;
    const posten = [];
    const P = (name, flaeche, angerechnet, grund, stufe) => posten.push({ name, flaeche, angerechnet, zaehlt: angerechnet > EPS, grund, stufe });
    const gebGrund = 'senkrechte Projektion der Außenmaße (§ 19 Abs. 2)';
    const zulI = G * grzW;
    let zulII, beschreibungII;

    if (e.fassung === 1962) {
      P('Gebäude (Außenmaß)', gebaeude, gebaeude, gebGrund, 1);
      P('Balkone, Loggien, Terrassen', T, T, 'BauNVO 1962: zählen mit (Terrassen nur, wenn mit dem Haus verbunden)', 1);
      if (kern) P('Garagen und überdachte Stellplätze', Ga, 0, 'In Kern-, Gewerbe- und Industriegebieten ohne Anrechnung (§ 19 Abs. 5)', 2);
      else if (Ga <= 0.1 * G + EPS) P('Garagen und überdachte Stellplätze', Ga, 0, 'Bis 1/10 des Grundstücks ohne Anrechnung (§ 19 Abs. 5)', 2);
      else { P('Garagen und überdachte Stellplätze', Ga, Ga, 'Mehr als 1/10 des Grundstücks: zählen voll mit (§ 19 Abs. 5)', 2); hinweise.push('Garagen und überdachte Stellplätze liegen über 1/10 des Grundstücks. Nach dem Wortlaut der Arbeitshilfe zählen sie dann ganz mit. Bitte im Bebauungsplan nachsehen.'); }
      P('Zufahrten und Zuwegungen', Zu, 0, 'Wege und Zufahrten zählen nicht (BauNVO 1962 bis 1977)', 2);
      P('Nebenanlagen (§ 14)', Ne, 0, 'Nebenanlagen zählen nicht (BauNVO 1962 bis 1977)', 2);
      P('Tiefgarage, unterirdische Anlagen', Ti, 0, 'Unterirdische Anlagen zählen nicht (BauNVO 1962 bis 1977)', 2);
      zulII = zulI;
      beschreibungII = 'mit Garagen und überdachten Stellplätzen (§ 19 Abs. 5): bis 1/10 des Grundstücks zählen sie nicht, darüber ganz';
    } else if (e.fassung === 1968) {
      P('Gebäude (Außenmaß)', gebaeude, gebaeude, gebGrund, 1);
      P('Balkone, Loggien, Terrassen', T, 0, '§ 19 Abs. 4 BauNVO 1968/1977: Balkone, Loggien und Terrassen zählen nicht', 1);
      if (kern) P('Garagen und überdachte Stellplätze', Ga, 0, 'In Kern-, Gewerbe- und Industriegebieten ohne Anrechnung (§ 21a)', 2);
      else P('Garagen und überdachte Stellplätze', Ga, Ga, 'Zählen mit, dürfen die zulässige Grundfläche aber bis 1/10 des Grundstücks überschreiten (§ 21a)', 2);
      P('Zufahrten und Zuwegungen', Zu, 0, 'Wege und Zufahrten zählen nicht (BauNVO 1962 bis 1977)', 2);
      P('Nebenanlagen (§ 14)', Ne, 0, 'Nebenanlagen zählen nicht (BauNVO 1962 bis 1977)', 2);
      P('Tiefgarage, unterirdische Anlagen', Ti, 0, 'Unterirdische Anlagen zählen nicht (BauNVO 1962 bis 1977)', 2);
      zulII = zulI + (kern ? 0 : 0.1 * G);
      beschreibungII = 'mit Garagen und überdachten Stellplätzen (§ 21a): die Grenze darf um 1/10 des Grundstücks überschritten werden';
    } else {
      P('Gebäude (Außenmaß)', gebaeude, gebaeude, gebGrund, 1);
      P('Balkone, Loggien, Terrassen', T, T, 'BauNVO 1990: gehören zur Hauptanlage (Terrassen nur, wenn mit dem Haus verbunden)', 1);
      P('Garagen und überdachte Stellplätze', Ga, Ga, '§ 19 Abs. 4 BauNVO 1990: zählen für die GRZ II mit', 2);
      P('Zufahrten und Zuwegungen', Zu, Zu, '§ 19 Abs. 4 BauNVO 1990: zählen für die GRZ II mit', 2);
      P('Nebenanlagen (§ 14)', Ne, Ne, '§ 19 Abs. 4 BauNVO 1990: zählen für die GRZ II mit', 2);
      P('Tiefgarage, unterirdische Anlagen', Ti, Ti, '§ 19 Abs. 4 BauNVO 1990: zählen für die GRZ II mit (Unterbauung)', 2);
      if (Ue > 0) P('Überlagerung (doppelt gezählte Fläche)', Ue, -Ue, 'Wo zum Beispiel eine Terrasse über der Tiefgarage liegt, wird die Fläche nur einmal gerechnet', 2);
      zulII = G * Math.max(grzW, Math.min(1.5 * grzW, 0.8));
      beschreibungII = 'mit Garagen, Stellplätzen, Zufahrten, Nebenanlagen und Tiefgarage (§ 19 Abs. 4): Überschreitung um 50 %, höchstens bis GRZ 0,8';
      if (grzW > 0.8) hinweise.push('Die GRZ liegt über 0,8. Dann gilt die Kappungsgrenze 0,8 nicht, die Überschreitung nach § 21a Abs. 3 kann greifen. Bitte im Bebauungsplan nachsehen.');
    }
    const stufe = (ist, zul) => ({ ist, zul, frei: Math.max(0, zul - ist), ueber: Math.max(0, ist - zul), ok: ist <= zul + EPS, wert: ist / G, wertZul: zul / G });
    const istI = posten.filter(p => p.stufe === 1).reduce((s, p) => s + p.angerechnet, 0);
    const istII = istI + posten.filter(p => p.stufe === 2).reduce((s, p) => s + p.angerechnet, 0);
    const I = stufe(istI, zulI), II = stufe(istII, zulII);
    II.beschreibung = beschreibungII;
    II.extra = istII - istI;
    return { G, gebaeude, hat: grzW > 0, I, II, posten, hinweise, gesamtOk: I.ok && II.ok };
  }
  window.grzRechnen = rechne;
  window.grzKlassiere = klassiere;
  window.grzFassungAusJahr = fassungAusJahr;

  // ================================================================ Seite
  const pp = window.planpruefer;
  if (!pp) return;
  const el = pp.el;
  const $ = id => document.getElementById(id);
  const de = (z, stellen = 2) => z.toLocaleString('de-DE', { minimumFractionDigits: stellen, maximumFractionDigits: stellen });
  const deKurz = z => z.toLocaleString('de-DE', { maximumFractionDigits: 3 });
  // Eingabe wie "1.250", "1250,5", "0,4" oder "0.4"
  function zahl(t) {
    let s = String(t == null ? '' : t).trim().replace(/\s|m²|m2/g, '');
    if (!s) return NaN;
    if (/^\d{1,3}(\.\d{3})+(,\d+)?$/.test(s)) s = s.replace(/\./g, '');
    return parseFloat(s.replace(',', '.'));
  }

  // ---------------------------------------------------------------- Taskleiste und Seite
  const leiste = $('taskleiste');
  leiste.append(el('span', 'task-pfeil', '›'));
  const gruppe = el('div', 'task-gruppe'); gruppe.id = 'taskGrz';
  const taskKnopf = el('button', 'task'); taskKnopf.type = 'button';
  taskKnopf.append(el('span', 'schritt', $('taskRaumprogramm') ? '3' : '2'), document.createTextNode('GRZ'));
  gruppe.append(taskKnopf); leiste.append(gruppe);

  const seite = el('main', 'seite versteckt'); seite.id = 'seiteGrz';
  seite.innerHTML = `
  <div class="bento">
    <section class="kachel banner breit gz-banner" aria-label="GRZ prüfen">
      <div>
        <h1>GRZ<br>PRÜFER</h1>
        <p>Wie viel darf auf das Grundstück? Trage Grundstücksgröße, GRZ und das Jahr des Bebauungsplans ein und lade deine Grundrisse hoch. Der Prüfer zeigt dir, was bebaut ist und was innerhalb der GRZ noch übrig ist, getrennt für GRZ I und GRZ II.</p>
      </div>
      <svg viewBox="0 0 260 220" aria-hidden="true" class="gz-bild">
        <rect x="20" y="30" width="200" height="160" rx="10" fill="none" stroke="#A7B6D0" stroke-width="3" stroke-dasharray="10 8"/>
        <rect class="gz-haus" x="48" y="62" width="96" height="70" rx="6" fill="#FFFFFF"/>
        <rect class="gz-terr" x="144" y="86" width="44" height="46" rx="6" fill="#A7B6D0"/>
        <rect class="gz-neben" x="150" y="146" width="48" height="30" rx="6" fill="#6F86B0"/>
        <path d="M48 62 L96 36 L144 62" fill="none" stroke="#1E2F4F" stroke-width="5" stroke-linejoin="round"/>
      </svg>
    </section>

    <div class="frage">Welche Vorgaben gelten?</div>
    <section class="kachel breit gz-eingabe" aria-label="Grundstück und Bebauungsplan">
      <div class="gz-reihe">
        <label class="gz-feld"><span>Grundstücksgröße</span><div class="gz-eing"><input id="gzGrund" type="text" inputmode="decimal" autocomplete="off" placeholder="zum Beispiel 600"><i>m²</i></div></label>
        <label class="gz-feld"><span>GRZ</span><div class="gz-eing"><input id="gzGrz" type="text" inputmode="decimal" autocomplete="off" placeholder="zum Beispiel 0,4"></div></label>
        <label class="gz-feld"><span>Baugebiet</span><div class="gz-eing"><select id="gzGebiet"><option value="uebrig">Wohn-, Misch- und übrige Gebiete</option><option value="kern">Kern-, Gewerbe-, Industriegebiet</option></select></div></label>
      </div>
      <div class="gz-trenner"></div>
      <div class="gz-titel">Welche BauNVO gilt?</div>
      <div class="gz-reihe">
        <label class="gz-feld"><span>BauNVO-Fassung</span><div class="gz-eing"><select id="gzFassung"><option value="0">bitte wählen</option><option value="1962">BauNVO 1962 (Bebauungspläne bis 1967)</option><option value="1968">BauNVO 1968/1977 (Bebauungspläne 1968 bis 1989)</option><option value="1990">BauNVO 1990 (Bebauungspläne ab 1990)</option></select></div></label>
      </div>
    </section>

    <div class="frage">Was soll geprüft werden?</div>
    <div class="kachel ablage gz-ablage breit" id="gzAblage" role="button" tabindex="0" aria-label="Grundrisse oder Lageplan als PDF auswählen">
      <input type="file" id="gzDatei" accept="application/pdf,.pdf" multiple>
      <div class="gross gz-gross">Grund&shy;risse</div>
      <div class="leise" id="gzDateiText">Alle Geschosse als PDF (und gern der Lageplan). Ohne Plan kannst du die Flächen später von Hand eintragen.</div>
      <div class="dateien" id="gzListe"></div>
    </div>

    <div class="kachel breit rp-los gz-los">
      <div>
        <div class="rp-los-titel">Bereit zum Rechnen?</div>
        <div class="leise" id="gzLosText">Erst Grundstücksgröße, GRZ und die BauNVO-Fassung eintragen.</div>
      </div>
      <button class="start rp-start" id="gzStart" type="button" disabled title="GRZ prüfen" aria-label="GRZ prüfen">
        <svg class="lupe" viewBox="0 0 32 32" aria-hidden="true"><circle cx="13" cy="13" r="8.5" fill="none" stroke="currentColor" stroke-width="3.5"/><path d="M19.5 19.5 L27 27" stroke="currentColor" stroke-width="4.5" stroke-linecap="round"/></svg>
        <svg class="rp-dreh" viewBox="0 0 82 82" aria-hidden="true"><circle cx="41" cy="41" r="37"/></svg>
      </button>
    </div>
    <div class="status" id="gzStatus" aria-live="polite"></div>
  </div>

  <section class="gz-ergebnis versteckt" id="gzErgebnis" aria-live="polite">
    <div class="kachel gz-kopf"><h2 id="gzTitel">Ergebnis</h2><div class="gz-chips" id="gzChips"></div></div>
    <div class="gz-doppel">
      <div class="kachel gz-karte" id="gzKarteI"></div>
      <div class="kachel gz-karte" id="gzKarteII"></div>
    </div>
    <div class="kachel gz-edit">
      <div class="gz-titel">Flächen aus dem Plan <span class="leise">Alles hier ist änderbar, das Ergebnis rechnet sofort neu.</span></div>
      <div class="gz-geschoss-kopf"><span>Geschoss</span><span>Fläche nach Außenmaß</span><span>ober&shy;irdisch</span><span></span></div>
      <div id="gzGeschosse"></div>
      <div class="gz-quelle" id="gzQuelle"></div>
      <p class="gz-klein">Die Gebäudegrundfläche ist die größte oberirdische Geschossfläche (senkrechte Projektion der Außenmaße, vorkragende Geschosse und Erker zählen mit). Das Kellergeschoss bleibt außen vor.</p>
      <div class="gz-trenner"></div>
      <div class="gz-reihe gz-extras">
        <label class="gz-feld"><span>Balkone, Loggien, Terrassen</span><div class="gz-eing"><input id="gzTerr" type="text" inputmode="decimal" autocomplete="off" value="0"><i>m²</i></div><small id="gzTerrNote"></small></label>
        <label class="gz-feld"><span>Garagen, Carports, überdachte Stellplätze</span><div class="gz-eing"><input id="gzGar" type="text" inputmode="decimal" autocomplete="off" value="0"><i>m²</i></div><small id="gzGarNote"></small></label>
        <label class="gz-feld"><span>Zufahrten, Zuwegungen, befestigte Wege</span><div class="gz-eing"><input id="gzZuf" type="text" inputmode="decimal" autocomplete="off" value="0"><i>m²</i></div><small>Steht nicht im Grundriss, bitte aus dem Lageplan eintragen.</small></label>
        <label class="gz-feld"><span>Nebenanlagen (Gartenhaus, Schuppen, Pool …)</span><div class="gz-eing"><input id="gzNeb" type="text" inputmode="decimal" autocomplete="off" value="0"><i>m²</i></div><small id="gzNebNote"></small></label>
        <label class="gz-feld"><span>Tiefgarage, unterirdische Anlagen</span><div class="gz-eing"><input id="gzTief" type="text" inputmode="decimal" autocomplete="off" value="0"><i>m²</i></div><small id="gzTiefNote"></small></label>
        <label class="gz-feld" id="gzUeberFeld"><span>Überlagerung (doppelt gezählt, nur BauNVO 1990)</span><div class="gz-eing"><input id="gzUeber" type="text" inputmode="decimal" autocomplete="off" value="0"><i>m²</i></div><small>Zum Beispiel Terrasse über der Tiefgarage.</small></label>
      </div>
    </div>
    <div class="kachel gz-wie">
      <div class="gz-titel">So wurde gerechnet <span class="leise">Regeln der Arbeitshilfe GRZ/GFZ</span></div>
      <div id="gzWie"></div>
      <div class="gz-hinweise" id="gzHinweise"></div>
    </div>
    <p class="gz-klein gz-recht">Das ist eine Hilfe für den Entwurf und ersetzt keine Prüfung durch die Bauaufsicht. Die Außenmaße aus dem Grundriss sind Schätzungen, Festsetzungen im Bebauungsplan können abweichen. Die Regeln folgen der BauNVO (bundesweit), wie sie die Arbeitshilfe der Bauaufsicht Frankfurt am Main (Stand Oktober 2014) erklärt. Landesrecht (zum Beispiel was im Bauwich zulässig ist) kann im Einzelfall abweichen.</p>
  </section>

  <button class="zurueck" id="gzZurueck" type="button"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 12 H5 M11 5 L4 12 L11 19"/></svg>Zurück</button>`;
  document.body.insertBefore(seite, document.querySelector('script'));

  // Übergang vom Raumprogramm: Kachel am Ende der Raumprogramm-Ergebnisse
  const rpErg = $('rpErgebnis');
  if (rpErg) {
    const weiter = el('section', 'kachel rp-weiter');
    weiter.innerHTML = `<svg viewBox="0 0 64 64" aria-hidden="true"><rect x="6" y="8" width="52" height="48" rx="6" fill="none" stroke="#A7B6D0" stroke-width="3" stroke-dasharray="6 5"/><rect x="14" y="22" width="26" height="22" rx="4" fill="#FFFFFF"/><rect x="40" y="30" width="12" height="14" rx="3" fill="#A7B6D0"/></svg>
      <div><b>Weiter zur GRZ-Prüfung</b><span>Passt der Entwurf auch zur GRZ des Bebauungsplans? Die Grundrisse nehme ich mit.</span></div>`;
    const k = el('button', 'rp-weiter-knopf', 'Zum GRZ-Prüfer →'); k.type = 'button'; k.addEventListener('click', () => oeffne());
    weiter.append(k); rpErg.append(weiter);
  }

  // ---------------------------------------------------------------- Zustand
  let dateien = [];
  let laeuft = false;
  let grundrisse = [];   // Antworten des Servers

  function oeffne() {
    if (!dateien.length) {
      const aus = (pp.rpPlaene && pp.rpPlaene()) || [];
      dateien = aus.length ? aus.slice() : pp.ergebnisse.map(e => e.datei);
      dateien = dateien.filter(f => f && f.name);
    }
    zeigeUpload();
    pp.zeigeSeite('seiteGrz');
  }
  taskKnopf.addEventListener('click', oeffne);
  $('gzZurueck').addEventListener('click', () => { if ($('rpErgebnis') && document.getElementById('seiteRaumprogramm')) pp.zeigeSeite('seiteRaumprogramm'); else if (pp.ergebnisse.length) pp.zeigeSeite2(); else pp.zeigeSeite('seite1'); });
  document.addEventListener('planpruefer:seite', ev => { gruppe.classList.toggle('aktiv', ev.detail.id === 'seiteGrz'); taskKnopf.classList.toggle('an', ev.detail.id === 'seiteGrz'); });

  // ---------------------------------------------------------------- Upload
  const ablage = $('gzAblage'), datei = $('gzDatei');
  ablage.addEventListener('click', ev => { if (ev.target.closest('.datei-chip')) return; datei.click(); });
  ablage.addEventListener('keydown', ev => { if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); datei.click(); } });
  datei.addEventListener('change', () => { nimmAuf(Array.from(datei.files)); datei.value = ''; });
  ablage.addEventListener('dragover', ev => { ev.preventDefault(); ablage.classList.add('ueber'); });
  ablage.addEventListener('dragleave', () => ablage.classList.remove('ueber'));
  ablage.addEventListener('drop', ev => { ev.preventDefault(); ablage.classList.remove('ueber'); nimmAuf(Array.from(ev.dataTransfer.files)); });
  function nimmAuf(liste) {
    for (const f of liste.filter(f => /\.pdf$/i.test(f.name) || f.type === 'application/pdf')) if (!dateien.some(g => g.name === f.name && g.size === f.size)) dateien.push(f);
    zeigeUpload();
  }
  function zeigeUpload() {
    const l = $('gzListe'); l.textContent = '';
    dateien.forEach((f, i) => {
      const c = el('span', 'datei-chip', f.name);
      const b = el('button', '', '×'); b.type = 'button'; b.title = 'Entfernen'; b.setAttribute('aria-label', f.name + ' entfernen');
      b.addEventListener('click', ev => { ev.stopPropagation(); dateien.splice(i, 1); zeigeUpload(); });
      c.append(b); l.append(c);
    });
    ablage.classList.toggle('erledigt', dateien.length > 0);
    pruefeBereit();
  }

  // ---------------------------------------------------------------- Eingabe
  function eingaben() {
    return { G: zahl($('gzGrund').value), grz: zahl($('gzGrz').value), fassung: +$('gzFassung').value, gebiet: $('gzGebiet').value };
  }
  function pruefeBereit() {
    const e = eingaben();
    const fehlt = !(e.G > 0) ? 'Es fehlt die Grundstücksgröße.' : !(e.grz > 0) ? 'Es fehlt die GRZ.' : !e.fassung ? 'Es fehlt die BauNVO-Fassung (bitte auswählen).' : '';
    $('gzStart').disabled = !!fehlt || laeuft;
    $('gzLosText').textContent = laeuft ? 'Einen Moment, die Grundrisse werden gelesen …' : fehlt || (dateien.length ? 'Mit der Lupe starten.' : 'Mit der Lupe starten. Ohne Grundriss trägst du die Flächen danach von Hand ein.');
  }
  ['gzGrund', 'gzGrz', 'gzGebiet'].forEach(id => $(id).addEventListener('input', () => { pruefeBereit(); neuRechnen(); }));
  $('gzFassung').addEventListener('change', () => { pruefeBereit(); neuRechnen(); });

  // ---------------------------------------------------------------- Grundrisse lesen
  function istOberirdisch(name) { return !/unter|keller|sockel/i.test(name || ''); }
  const kurzName = n => n.replace(/\.pdf$/i, '');
  function bauZustand() {
    const floors = []; const extras = { terrasse: [], garage: [], nebenanlage: [], tiefgarage: [] };
    const quellen = [];
    for (const g of grundrisse) {
      const mitRaeumen = (g.gruppen || []).filter(x => (x.raeume || []).length);
      mitRaeumen.forEach(gr => {
        const name = gr.name || kurzName(g.datei);
        let ngf = 0;
        for (const r of gr.raeume) {
          const art = klassiere(r.name);
          if (art === 'gebaeude') ngf += r.flaeche;
          else extras[art].push({ name: r.name || art, flaeche: r.flaeche });
        }
        if (ngf <= 0) return;
        let aussen, quelle;
        if (g.rechteck && mitRaeumen.length === 1) { aussen = g.rechteck.breite * g.rechteck.tiefe; quelle = `${name}: Gebäuderechteck aus den Maßketten (${de(g.rechteck.breite)} × ${de(g.rechteck.tiefe)} m). Bei L- oder U-Form ist das etwas zu groß.`; }
        else { aussen = ngf * 1.2; quelle = `${name}: Raumflächen ${de(ngf)} m² mal 1,20 für Wände geschätzt.`; }
        floors.push({ name, aussen: Math.round(aussen * 100) / 100, oberirdisch: istOberirdisch(name) });
        quellen.push(quelle);
      });
    }
    return { floors, extras, quellen };
  }

  $('gzStart').addEventListener('click', async () => {
    if (laeuft) return;
    const e = eingaben(); if (!(e.G > 0) || !e.fassung) return;
    laeuft = true; $('gzStart').classList.add('laeuft'); pruefeBereit(); zeigeStatus('');
    try {
      grundrisse = [];
      for (let i = 0; i < dateien.length; i++) {
        const f = dateien[i];
        zeigeStatus(`Lese ${dateien.length > 1 ? `Grundriss ${i + 1} von ${dateien.length}: ` : ''}${f.name} (bei Werkplänen mit Maßketten dauert das etwas länger) …`);
        const r = await fetch('/grz-grundriss', { method: 'POST', headers: { 'X-Dateiname': encodeURIComponent(f.name) }, body: f });
        const d = await r.json().catch(() => ({ fehler: 'Antwort des Servers nicht lesbar' }));
        if (!r.ok) throw new Error(`${f.name}: ${d.fehler || 'Fehler beim Lesen'}${r.status === 404 ? ' (Server bitte neu starten, damit das Add-on läuft)' : ''}`);
        grundrisse.push(d);
      }
      const z = bauZustand();
      zeigeStatus('');
      baueEditor(z);
      $('gzErgebnis').classList.remove('versteckt');
      neuRechnen();
      $('gzErgebnis').scrollIntoView({ behavior: 'smooth', block: 'start' });
      if (dateien.length && !z.floors.length) zeigeStatus('In den Grundrissen wurden keine Raumflächen gefunden. Bitte die Geschossfläche unten von Hand eintragen.', true);
    } catch (err) {
      zeigeStatus(err instanceof TypeError ? 'Der Planprüfer-Server ist nicht erreichbar.' : err.message, true);
    } finally { laeuft = false; $('gzStart').classList.remove('laeuft'); pruefeBereit(); }
  });
  function zeigeStatus(text, fehler) {
    const s = $('gzStatus'); s.textContent = '';
    if (!text) return;
    if (fehler) s.append(el('div', 'meldung-fehler', text)); else s.textContent = text;
  }

  // ---------------------------------------------------------------- Editor der Flächen
  function baueEditor(z) {
    const box = $('gzGeschosse'); box.textContent = '';
    if (!z.floors.length) z.floors.push({ name: 'Erdgeschoss', aussen: 0, oberirdisch: true });
    z.floors.forEach(f => box.append(geschossZeile(f)));
    $('gzQuelle').textContent = z.quellen.join('  ');
    const summe = a => z.extras[a].reduce((s, r) => s + r.flaeche, 0);
    const setze = (id, art, noteId) => {
      $(id).value = deKurz(Math.round(summe(art) * 100) / 100);
      $(noteId).textContent = z.extras[art].length ? 'Aus dem Plan: ' + z.extras[art].map(r => `${r.name} ${de(r.flaeche)} m²`).join(', ') + '. Außenmaß prüfen.' : '';
    };
    setze('gzTerr', 'terrasse', 'gzTerrNote'); setze('gzGar', 'garage', 'gzGarNote'); setze('gzNeb', 'nebenanlage', 'gzNebNote'); setze('gzTief', 'tiefgarage', 'gzTiefNote');
    $('gzZuf').value = '0'; $('gzUeber').value = '0';
  }
  function geschossZeile(f) {
    const z = el('div', 'gz-geschoss');
    z.innerHTML = `<input class="gz-g-name" type="text" aria-label="Name des Geschosses"><div class="gz-eing"><input class="gz-g-flaeche" type="text" inputmode="decimal" aria-label="Fläche nach Außenmaß in Quadratmetern"><i>m²</i></div>
      <label class="gz-g-check"><input type="checkbox" class="gz-g-ober" aria-label="oberirdisch"></label><button type="button" class="gz-weg" title="Geschoss entfernen" aria-label="Geschoss entfernen">×</button>`;
    z.querySelector('.gz-g-name').value = f.name;
    z.querySelector('.gz-g-flaeche').value = deKurz(f.aussen);
    z.querySelector('.gz-g-ober').checked = f.oberirdisch !== false;
    z.addEventListener('input', neuRechnen); z.addEventListener('change', neuRechnen);
    z.querySelector('.gz-weg').addEventListener('click', () => { z.remove(); neuRechnen(); });
    return z;
  }
  ['gzTerr', 'gzGar', 'gzZuf', 'gzNeb', 'gzTief', 'gzUeber'].forEach(id => $(id).addEventListener('input', neuRechnen));

  function lies() {
    const e = eingaben();
    e.floors = Array.from($('gzGeschosse').children).map(z => ({
      name: z.querySelector('.gz-g-name').value.trim(), aussen: zahl(z.querySelector('.gz-g-flaeche').value) || 0, oberirdisch: z.querySelector('.gz-g-ober').checked
    }));
    const n = id => zahl($(id).value) || 0;
    e.terrassen = n('gzTerr'); e.garagen = n('gzGar'); e.zufahrten = n('gzZuf'); e.nebenanlagen = n('gzNeb'); e.tiefgarage = n('gzTief'); e.ueberlagerung = n('gzUeber');
    return e;
  }

  // ---------------------------------------------------------------- Ergebnis zeichnen
  function neuRechnen() {
    if ($('gzErgebnis').classList.contains('versteckt')) return;
    const e = lies();
    $('gzUeberFeld').classList.toggle('versteckt', e.fassung !== 1990);
    const res = rechne(e);
    if (!res) { $('gzKarteI').textContent = 'Bitte Grundstücksgröße und BauNVO-Fassung eintragen.'; $('gzKarteII').textContent = ''; return; }
    zeichne(e, res);
  }

  function balken(ist, zul, titel) {
    const total = Math.max(ist, zul) * 1.1 || 1;
    const b = el('div', 'gz-balken'); b.setAttribute('role', 'img'); b.setAttribute('aria-label', `${titel}: ${de(ist)} von ${de(zul)} Quadratmetern`);
    const f = el('div', 'gz-fuell'); f.style.width = (Math.min(ist, zul) / total * 100) + '%'; b.append(f);
    if (ist > zul) { const u = el('div', 'gz-ueber'); u.style.left = (zul / total * 100) + '%'; u.style.width = ((ist - zul) / total * 100) + '%'; b.append(u); }
    const m = el('div', 'gz-marke'); m.style.left = (zul / total * 100) + '%'; m.append(el('span', '', 'zulässig')); b.append(m);
    return b;
  }
  function zahlenZeile(items) {
    const z = el('div', 'gz-zahlen');
    items.forEach(([titel, wert, klasse]) => { const k = el('div', 'gz-zahl' + (klasse ? ' ' + klasse : '')); k.append(el('small', '', titel), el('b', '', wert)); z.append(k); });
    return z;
  }
  function schild(ok, text) { return el('span', 'gz-schild ' + (ok ? 'ok' : 'ueber'), (ok ? '✓ ' : '! ') + text); }

  // Grundstück als 10 mal 10 Kästchen: segmente = [[Art, m², Text], ...] in dieser Reihenfolge, der Rest ist übriges Grundstück
  function raster(G, segmente) {
    const wrap = el('div', 'gz-raster-zeile');
    const r = el('div', 'gz-raster'); r.setAttribute('aria-hidden', 'true');
    let rest = 100;
    const leg = el('div', 'gz-legende');
    for (const [art, m2, text] of segmente) {
      if (!(m2 > EPS)) continue;
      const n = Math.min(rest, Math.max(1, Math.round(m2 / G * 100))); rest -= n;
      for (let i = 0; i < n; i++) r.append(el('i', 'gz-c-' + art));
      const z = el('div', 'gz-leg'); z.append(el('i', 'gz-c-' + art), el('span', '', `${text}: ${de(m2)} m²`)); leg.append(z);
    }
    for (let i = 0; i < rest; i++) r.append(el('i', 'gz-c-rest'));
    wrap.append(r, leg);
    return wrap;
  }

  function karte(box, titel, untertitel, s, G, e, segmente, wortDavor) {
    box.textContent = '';
    const kopf = el('div', 'gz-karte-kopf'); kopf.append(el('h3', '', titel), schild(s.ok, s.ok ? 'eingehalten' : 'überschritten'));
    box.append(kopf, el('div', 'gz-stufe', untertitel));
    box.append(zahlenZeile([
      ['bebaut (Ist)', de(s.ist) + ' m²'],
      ['zulässig (GRZ ' + deKurz(Math.round(s.wertZul * 1000) / 1000) + ')', de(s.zul) + ' m²'],
      [s.ok ? 'noch frei' : 'zu viel', de(s.ok ? s.frei : s.ueber) + ' m²', s.ok ? 'frei' : 'stark']
    ]));
    box.append(balken(s.ist, s.zul, titel));
    box.append(el('p', 'gz-ist', `Ist-Zustand: ${wortDavor} ${deKurz(Math.round(s.wert * 1000) / 1000)}, erlaubt ${deKurz(Math.round(s.wertZul * 1000) / 1000)}. ` +
      (s.ok ? `Innerhalb der Vorgabe bleiben noch ${de(s.frei)} m² (${de(s.frei / G * 100, 1)} % des Grundstücks).` : `Die Vorgabe ist um ${de(s.ueber)} m² überschritten.`)));
    box.append(raster(G, segmente));
  }

  function zeichne(e, res) {
    const G = res.G;
    $('gzTitel').textContent = `Grundstück ${de(G, 0)} m² · ${FASSUNG_NAME[e.fassung]} · GRZ ${deKurz(e.grz)}`;
    const chips = $('gzChips'); chips.textContent = '';
    chips.append(schild(res.I.ok, 'GRZ I ' + (res.I.ok ? 'eingehalten' : 'überschritten')), schild(res.II.ok, 'GRZ II ' + (res.II.ok ? 'eingehalten' : 'überschritten')));
    const terr = res.posten.filter(p => p.stufe === 1 && p.name.startsWith('Balkone')).reduce((s, p) => s + p.angerechnet, 0);
    const geb = Math.min(res.gebaeude, G);
    const gebSeg = ['geb', geb, 'Gebäude'], terrSeg = ['terr', terr, 'Terrassen und Balkone (angerechnet)'];
    karte($('gzKarteI'), 'GRZ I', 'Hauptanlagen: ' + (e.fassung === 1968 ? 'Gebäude (Terrassen und Balkone zählen hier nicht)' : 'Gebäude samt Terrassen und Balkonen'), res.I, G, e,
      [gebSeg, terrSeg, ['frei', res.I.frei, 'noch frei bis zur Grenze']], 'GRZ I');
    const extra = Math.max(0, res.II.extra);
    karte($('gzKarteII'), 'GRZ II', res.II.beschreibung, res.II, G, e,
      [gebSeg, terrSeg, ['weit', extra, 'weitere angerechnete Flächen'], ['frei', res.II.frei, 'noch frei bis zur Grenze']], 'GRZ II');
    wie(e, res);
  }

  function wie(e, res) {
    const box = $('gzWie'); box.textContent = '';
    [[1, 'GRZ I: Hauptanlagen'], [2, 'GRZ II: weitere Anlagen']].forEach(([st, titel]) => {
      const b = el('div', 'gz-wie-block'); b.append(el('h4', '', titel + ' (' + FASSUNG_NAME[e.fassung] + ')'));
      res.posten.filter(p => p.stufe === st).forEach(p => {
        const z = el('div', 'gz-wie-zeile' + (p.zaehlt ? ' ja' : ''));
        z.append(el('span', 'gz-wie-zeichen', p.zaehlt ? '✓' : '–'), el('span', 'gz-wie-name', p.name), el('span', 'gz-wie-zahl', p.angerechnet === p.flaeche || !p.flaeche ? de(p.flaeche) + ' m²' : de(p.flaeche) + ' m², angerechnet ' + de(p.angerechnet) + ' m²'), el('span', 'gz-wie-grund', p.grund));
        b.append(z);
      });
      box.append(b);
    });
    const h = $('gzHinweise'); h.textContent = '';
    res.hinweise.forEach(t => h.append(el('div', 'gz-meldung', t)));
  }

  pruefeBereit();
})();
