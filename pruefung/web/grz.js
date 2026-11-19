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
    if (/befestigt|zufahrt|zuweg|einfahrt|\bwege?\b|pflaster|versiegelt|stellfl[aä]che/.test(n)) return 'zufahrt';
    return 'gebaeude';
  }

  // Erklärung in einfacher Sprache zu einem Posten (für das (i) in "So wurde gerechnet")
  function erklaere(p, f) {
    const n = p.name;
    if (n.startsWith('Gebäude')) return 'Es zählt, was das Haus von oben gesehen überdeckt: Außenwände samt vorkragenden Geschossen und Erkern. Dachüberstände, Gesimse und wenige Eingangsstufen bleiben außen vor.';
    if (n.startsWith('Balkone')) return f === 1968 ? 'Seit der BauNVO 1968 zählen Balkone, Loggien und Terrassen bei der GRZ nicht mehr mit.'
      : f === 1962 ? 'Nach der BauNVO 1962 zählen Balkone, Loggien und Terrassen am Haus zur bebauten Fläche.'
      : 'Nach der BauNVO 1990 gehören Terrassen und Balkone, die zum Haus gehören, zur Hauptanlage und zählen schon in der GRZ I.';
    if (n.startsWith('Garagen')) return f === 1962 ? 'Garagen und überdachte Stellplätze bleiben frei, solange sie zusammen höchstens ein Zehntel des Grundstücks einnehmen. Darüber zählen sie nach dem Wortlaut der Arbeitshilfe ganz mit. In Kern-, Gewerbe- und Industriegebieten zählen sie nicht.'
      : f === 1968 ? 'Garagen und überdachte Stellplätze zählen in der GRZ II mit. Dafür darf die zulässige Grundfläche um ein Zehntel des Grundstücks überschritten werden (§ 21a). In Kern-, Gewerbe- und Industriegebieten zählen sie nicht.'
      : 'Seit 1990 zählen Garagen und überdachte Stellplätze mit, aber erst in der GRZ II. Dafür darf die GRZ um 50 % überschritten werden, höchstens bis 0,8.';
    if (n.startsWith('Zufahrten')) return f < 1990 ? 'Wege und Zufahrten werden nach den älteren Fassungen (bis 1977) nicht mitgerechnet.' : 'Seit 1990 zählen auch Zufahrten und Zuwegungen mit, aber erst in der GRZ II (Überschreitung um 50 %, höchstens bis 0,8).';
    if (n.startsWith('Nebenanlagen')) return f < 1990 ? 'Nebenanlagen wie Gartenhaus, Schuppen oder Pool zählen nach den älteren Fassungen (bis 1977) nicht mit.' : 'Nebenanlagen wie Gartenhaus, Schuppen oder Pool zählen seit 1990 mit, aber erst in der GRZ II.';
    if (n.startsWith('Tiefgarage')) return f < 1990 ? 'Unterirdische Anlagen bleiben nach den älteren Fassungen (bis 1977) außen vor, weil nur zählt, was das Grundstück überdeckt.' : 'Seit 1990 zählt auch, was das Grundstück unterbaut, zum Beispiel eine Tiefgarage, in der GRZ II.';
    if (n.startsWith('Überlagerung')) return 'Liegt zum Beispiel eine Terrasse über der Tiefgarage, würde die Fläche doppelt gezählt. Sie darf nur einmal angerechnet werden.';
    return '';
  }

  // GRZ I = Hauptanlagen, GRZ II = GRZ I plus die Flächen, die erst die GRZ II mitzählt. Beides mit eigener Grenze.
  // e.anbau (m²) ist ein zusätzlicher Anbau am Haus (für "Was wäre, wenn"), er vergrößert die Gebäudegrundfläche.
  function rechne(e) {
    const G = e.G;
    if (!(G > 0) || !e.fassung) return null;
    const hinweise = [];
    const ober = (e.floors || []).filter(f => f.oberirdisch !== false);
    const gebaeude = ober.reduce((m, f) => Math.max(m, +f.aussen || 0), 0) + (+e.anbau || 0);
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
    posten.forEach(p => { p.einfach = erklaere(p, e.fassung); });
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
  const taskKnopf = el('button', 'task'); taskKnopf.type = 'button'; taskKnopf.title = 'GRZ-Prüfer';
  taskKnopf.append(el('span', 'schritt', $('taskRaumprogramm') ? '3' : '2'), document.createTextNode('GRZ'));
  gruppe.append(taskKnopf); leiste.append(gruppe);

  const seite = el('main', 'seite versteckt'); seite.id = 'seiteGrz';
  seite.innerHTML = `
  <div class="bento" id="gzEingabe">
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
        <label class="gz-feld"><span>BauNVO-Fassung</span><div class="gz-eing"><select id="gzFassung"><option value="0">bitte wählen</option><option value="1962">BauNVO 1962 (Pläne bis 1967)</option><option value="1968">BauNVO 1968/1977 (Pläne 1968 bis 1989)</option><option value="1990">BauNVO 1990 (Pläne ab 1990)</option></select></div></label>
      </div>
    </section>

    <div class="frage versteckt" id="gzFrageWeg">Wie möchtest du weitermachen?</div>
    <label class="kachel wahl gz-weg-wahl versteckt" id="gzWegPlanKachel">
      <input type="radio" name="gzWeg" id="gzWegPlan" value="plan">
      <span class="name">Mit Plan</span>
      <span class="klein">Grundriss oder Lageplan als PDF hochladen. Der Prüfer liest die Flächen, danach kannst du alles korrigieren.</span>
      <span class="haken" aria-hidden="true"></span>
    </label>
    <label class="kachel wahl gz-weg-wahl versteckt" id="gzWegHandKachel">
      <input type="radio" name="gzWeg" id="gzWegHand" value="hand">
      <span class="name">Manuell eingeben</span>
      <span class="klein">Du trägst die bebauten Flächen selbst ein, ganz ohne Plan.</span>
      <span class="haken" aria-hidden="true"></span>
    </label>

    <div class="kachel ablage gz-ablage breit versteckt" id="gzAblage" role="button" tabindex="0" aria-label="Grundrisse oder Lageplan als PDF auswählen">
      <input type="file" id="gzDatei" accept="application/pdf,.pdf" multiple>
      <div class="gross gz-gross">Grund&shy;risse</div>
      <div class="leise" id="gzDateiText">Alle Geschosse als PDF und, wenn vorhanden, der Lageplan. Nach der Prüfung kannst du alle Flächen noch korrigieren.</div>
      <div class="dateien" id="gzListe"></div>
    </div>

    <section class="kachel breit gz-manuell versteckt" id="gzManuell" aria-label="Flächen von Hand eingeben">
      <div class="gz-titel">Bebaute Flächen <span class="leise">Alles in m² nach Außenmaß. Leere Felder zählen als 0.</span></div>
      <div class="gz-reihe">
        <label class="gz-feld"><span>Gebäudegrundfläche (Wohnhaus)</span><div class="gz-eing"><input id="gzMGeb" type="text" inputmode="decimal" autocomplete="off" placeholder="zum Beispiel 120"><i>m²</i></div><small>Das Haus von oben gesehen, größtes oberirdisches Geschoss.</small></label>
        <label class="gz-feld"><span>Balkone, Loggien, Terrassen</span><div class="gz-eing"><input id="gzMTerr" type="text" inputmode="decimal" autocomplete="off"><i>m²</i></div></label>
        <label class="gz-feld"><span>Garagen, Carports, überdachte Stellplätze</span><div class="gz-eing"><input id="gzMGar" type="text" inputmode="decimal" autocomplete="off"><i>m²</i></div></label>
        <label class="gz-feld"><span>Zufahrten, Zuwegungen, befestigte Wege</span><div class="gz-eing"><input id="gzMZuf" type="text" inputmode="decimal" autocomplete="off"><i>m²</i></div></label>
        <label class="gz-feld"><span>Nebenanlagen (Gartenhaus, Schuppen, Pool …)</span><div class="gz-eing"><input id="gzMNeb" type="text" inputmode="decimal" autocomplete="off"><i>m²</i></div></label>
        <label class="gz-feld"><span>Tiefgarage, unterirdische Anlagen</span><div class="gz-eing"><input id="gzMTief" type="text" inputmode="decimal" autocomplete="off"><i>m²</i></div></label>
        <label class="gz-feld versteckt" id="gzMUeberFeld"><span>Überlagerung (doppelt gezählt, nur BauNVO 1990)</span><div class="gz-eing"><input id="gzMUeber" type="text" inputmode="decimal" autocomplete="off"><i>m²</i></div><small>Zum Beispiel Terrasse über der Tiefgarage.</small></label>
      </div>
    </section>

    <div class="kachel breit rp-los gz-los versteckt" id="gzLos">
      <div>
        <div class="rp-los-titel">Bereit zum Rechnen?</div>
        <div class="leise" id="gzLosText">Erst Grundstücksgröße, GRZ und die BauNVO-Fassung eintragen.</div>
      </div>
      <button class="start rp-start" id="gzStart" type="button" disabled title="GRZ prüfen" aria-label="GRZ prüfen">
        <svg class="lupe" viewBox="0 0 32 32" aria-hidden="true"><circle cx="13" cy="13" r="8.5" fill="none" stroke="currentColor" stroke-width="3.5"/><path d="M19.5 19.5 L27 27" stroke="currentColor" stroke-width="4.5" stroke-linecap="round"/></svg>
        <svg class="rp-dreh" viewBox="0 0 82 82" aria-hidden="true"><circle cx="41" cy="41" r="37"/></svg>
      </button>
    </div>    <div class="status" id="gzStatus" aria-live="polite"></div>
  </div>

  <section class="gz-ergebnis versteckt" id="gzErgebnis" aria-live="polite">
    <div class="kachel gz-kopf"><div class="gz-kopf-text"><h2 id="gzTitel">Ergebnis</h2><p class="gz-titelsatz" id="gzTitelsatz"></p></div><div class="gz-chips" id="gzChips"></div></div>
    <div class="gz-doppel">
      <div class="kachel gz-karte" id="gzKarteI"></div>
      <div class="kachel gz-karte" id="gzKarteII"></div>
    </div>
    <div class="kachel gz-wenn" id="gzWenn">
      <div class="gz-titel">Was wäre, wenn …? <span class="leise">Schiebe einen Baustein dazu und sieh sofort, was die GRZ sagt.</span></div>
      <div id="gzWennZeilen"></div>
      <div class="gz-wenn-fuss"><span class="gz-klein" id="gzWennHinweis">Die Bausteine kommen zusätzlich zu den eingetragenen Flächen. Sie ändern nur die Vorschau, nicht die Eingaben.</span><button type="button" class="gz-knopf hell" id="gzWennReset">Zurücksetzen</button></div>
    </div>
    <div class="kachel gz-edit">
      <div class="gz-titel"><span id="gzEditTitel">Flächen aus dem Plan</span> <span class="leise">Alles hier ist änderbar, das Ergebnis rechnet sofort neu.</span></div>
      <div class="gz-geschoss-kopf"><span>Geschoss</span><span>Fläche nach Außenmaß</span><span title="oberirdisches Geschoss, zählt für die Gebäudegrundfläche">zählt mit</span><span></span></div>
      <div id="gzGeschosse"></div>
      <div class="gz-quelle" id="gzQuelle"></div>
      <p class="gz-klein">Die Gebäudegrundfläche ist die größte oberirdische Geschossfläche (senkrechte Projektion der Außenmaße, vorkragende Geschosse und Erker zählen mit). Das Kellergeschoss bleibt außen vor.</p>
      <div class="gz-trenner"></div>
      <div class="gz-reihe gz-extras">
        <label class="gz-feld"><span>Balkone, Loggien, Terrassen</span><div class="gz-eing"><input id="gzTerr" type="text" inputmode="decimal" autocomplete="off" value="0"><i>m²</i></div><small id="gzTerrNote"></small></label>
        <label class="gz-feld"><span>Garagen, Carports, überdachte Stellplätze</span><div class="gz-eing"><input id="gzGar" type="text" inputmode="decimal" autocomplete="off" value="0"><i>m²</i></div><small id="gzGarNote"></small></label>
        <label class="gz-feld"><span>Zufahrten, Zuwegungen, befestigte Wege</span><div class="gz-eing"><input id="gzZuf" type="text" inputmode="decimal" autocomplete="off" value="0"><i>m²</i></div><small id="gzZufNote"></small></label>
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

  <button class="zurueck" id="gzZurueck" type="button"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 12 H5 M11 5 L4 12 L11 19"/></svg><span id="gzZurueckText">Zurück</span></button>`;
  // vor das erste Skript im <body> (ein Skript im <head>, etwa der Demo-Baustein der Online-Version, ist kein Platz für eine Seite)
  document.body.insertBefore(seite, document.body.querySelector(':scope > script'));

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
    if (dateien.length && !weg()) $('gzWegPlan').checked = true;   // Pläne aus den vorigen Schritten: gleich der Weg mit Plan
    zeigeUpload();
    pp.zeigeSeite('seiteGrz');
  }
  taskKnopf.addEventListener('click', oeffne);
  $('gzZurueck').addEventListener('click', () => { if (!$('gzErgebnis').classList.contains('versteckt')) { zeigeAnsicht('eingabe'); return; } if ($('rpErgebnis') && document.getElementById('seiteRaumprogramm')) pp.zeigeSeite('seiteRaumprogramm'); else if (pp.ergebnisse.length) pp.zeigeSeite2(); else pp.zeigeSeite('seite1'); });
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
  const weg = () => { const r = document.querySelector('input[name=gzWeg]:checked'); return r ? r.value : ''; };
  function pruefeBereit() {
    const e = eingaben();
    const fehltVor = !(e.G > 0) ? 'Es fehlt die Grundstücksgröße.' : !(e.grz > 0) ? 'Es fehlt die GRZ.' : !e.fassung ? 'Es fehlt die BauNVO-Fassung (bitte auswählen).' : '';
    const ok = !fehltVor, w = weg();
    // Erst wenn die Vorgaben stehen, kommt die Frage "Mit Plan oder manuell?", danach der passende Block und die Lupe
    ['gzFrageWeg', 'gzWegPlanKachel', 'gzWegHandKachel'].forEach(id => $(id).classList.toggle('versteckt', !ok));
    $('gzAblage').classList.toggle('versteckt', !(ok && w === 'plan'));
    $('gzManuell').classList.toggle('versteckt', !(ok && w === 'hand'));
    $('gzLos').classList.toggle('versteckt', !(ok && w));
    $('gzMUeberFeld').classList.toggle('versteckt', e.fassung !== 1990);
    let fehlt = fehltVor;
    if (!fehlt && w === 'plan' && !dateien.length) fehlt = 'Es fehlt noch ein Grundriss oder Lageplan.';
    else if (!fehlt && w === 'hand' && !(zahl($('gzMGeb').value) > 0)) fehlt = 'Es fehlt noch die Gebäudegrundfläche.';
    $('gzStart').disabled = !!fehlt || laeuft || !w;
    $('gzLosText').textContent = laeuft ? (w === 'plan' ? 'Einen Moment, die Grundrisse werden gelesen …' : 'Einen Moment …') : fehlt || 'Mit der Lupe starten.';
  }  ['gzGrund', 'gzGrz', 'gzGebiet'].forEach(id => $(id).addEventListener('input', () => { pruefeBereit(); neuRechnen(); }));
  $('gzFassung').addEventListener('change', () => { pruefeBereit(); neuRechnen(); });

  document.querySelectorAll('input[name=gzWeg]').forEach(r => r.addEventListener('change', pruefeBereit));
  ['gzMGeb', 'gzMTerr', 'gzMGar', 'gzMZuf', 'gzMNeb', 'gzMTief', 'gzMUeber'].forEach(id => $(id).addEventListener('input', pruefeBereit));

  // Zwei Ansichten: Eingabe (Vorgaben, Weg, Plan oder Flächen) und Ergebnis (Karten, Was wäre wenn, Flächen korrigieren)
  function zeigeAnsicht(a) {
    $('gzEingabe').classList.toggle('versteckt', a === 'ergebnis');
    $('gzErgebnis').classList.toggle('versteckt', a !== 'ergebnis');
    $('gzZurueckText').textContent = a === 'ergebnis' ? 'Zurück zur Eingabe' : 'Zurück';
    window.scrollTo(0, 0);
  }

  // ---------------------------------------------------------------- Grundrisse lesen
  function istOberirdisch(name) { return !/unter|keller|sockel/i.test(name || ''); }
  const kurzName = n => n.replace(/\.pdf$/i, '');
  function bauZustand() {
    const floors = []; const extras = { terrasse: [], garage: [], nebenanlage: [], tiefgarage: [], zufahrt: [] };
    const quellen = [];
    const hausLage = [];   // Gebäude-Grundflächen aus einem Lageplan (Wohnhaus 118,39 m²): genauer als jede Schätzung
    const gleich = (a, b) => Math.abs(a - b) < 0.006;
    for (const g of grundrisse) {
      // Lageplan-Beschriftungen (Name mit Fläche darunter) kommen direkt in die Liste
      const lage = g.flaechen || [];
      for (const l of lage) {
        const art = klassiere(l.name);
        if (art === 'gebaeude') hausLage.push({ name: l.name, flaeche: l.flaeche, datei: g.datei });
        else extras[art].push({ name: l.name, flaeche: l.flaeche });
      }
      const mitRaeumen = (g.gruppen || []).filter(x => (x.raeume || []).length);
      mitRaeumen.forEach(gr => {
        const name = gr.name || kurzName(g.datei);
        let ngf = 0;
        for (const r of gr.raeume) {
          if (lage.some(l => gleich(l.flaeche, r.flaeche))) continue;   // steht schon als Lageplan-Fläche da, nicht doppelt zählen
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
    if (hausLage.length) {
      const summe = hausLage.reduce((s, h) => s + h.flaeche, 0);
      // Die Gebäudegrundfläche kommt aus dem Lageplan. Geschosse aus Grundrissen bleiben in der Liste, zählen aber nicht mit (Häkchen "zählt mit" ist aus).
      floors.forEach(f => { f.oberirdisch = false; });
      floors.unshift({ name: hausLage.length === 1 ? hausLage[0].name + ' (Lageplan)' : 'Gebäude (Lageplan)', aussen: Math.round(summe * 100) / 100, oberirdisch: true });
      quellen.unshift(`Lageplan: ${hausLage.map(h => `${h.name} ${de(h.flaeche)} m²`).join(', ')} als Gebäudegrundfläche übernommen.` + (floors.length > 1 ? ' Die Geschosse aus den Grundrissen sind abgewählt, damit sie die genaue Fläche nicht überlagern. Wer sie nutzen will, setzt das Häkchen wieder.' : ''));
    }
    return { floors, extras, quellen };
  }

  $('gzStart').addEventListener('click', async () => {
    if (laeuft) return;
    const e = eingaben(); const w = weg();
    if (!(e.G > 0) || !e.fassung || !w) return;
    laeuft = true; $('gzStart').classList.add('laeuft'); pruefeBereit(); zeigeStatus('');
    try {
      let z;
      if (w === 'plan') {
        grundrisse = [];
        for (let i = 0; i < dateien.length; i++) {
          const f = dateien[i];
          zeigeStatus(`Lese ${dateien.length > 1 ? `Grundriss ${i + 1} von ${dateien.length}: ` : ''}${f.name} (bei Werkplänen mit Maßketten dauert das etwas länger) …`);
          const r = await fetch('grz-grundriss', { method: 'POST', headers: { 'X-Dateiname': encodeURIComponent(f.name) }, body: f });
          const d = await r.json().catch(() => ({ fehler: 'Antwort des Servers nicht lesbar' }));
          if (!r.ok) throw new Error(`${f.name}: ${d.fehler || 'Fehler beim Lesen'}${r.status === 404 ? ' (Server bitte neu starten, damit das Add-on läuft)' : ''}`);
          grundrisse.push(d);
        }
        z = bauZustand();
      } else {
        const n = id => zahl($(id).value) || 0;
        z = { floors: [{ name: 'Gebäude (Eingabe)', aussen: n('gzMGeb'), oberirdisch: true }], extras: {}, quellen: ['Von Hand eingegeben.'],
          manuell: { terrasse: n('gzMTerr'), garage: n('gzMGar'), zufahrt: n('gzMZuf'), nebenanlage: n('gzMNeb'), tiefgarage: n('gzMTief'), ueber: n('gzMUeber') } };
      }
      zeigeStatus('');
      baueEditor(z, w);
      zeigeAnsicht('ergebnis');
      $('gzWennReset').click();   // neue Prüfung: die Was-wäre-wenn-Regler beginnen wieder bei 0
      animiere = true;
      neuRechnen();
    } catch (err) {
      zeigeStatus(err instanceof TypeError ? 'Der Planprüfer-Server ist nicht erreichbar.' : err.message, true);
    } finally { laeuft = false; $('gzStart').classList.remove('laeuft'); pruefeBereit(); }
  });  function zeigeStatus(text, fehler) {
    const s = $('gzStatus'); s.textContent = '';
    if (!text) return;
    if (fehler) s.append(el('div', 'meldung-fehler', text)); else s.textContent = text;
  }

  // ---------------------------------------------------------------- Editor der Flächen
  function baueEditor(z, w) {
    const box = $('gzGeschosse'); box.textContent = '';
    if (!z.floors.length) { z.floors.push({ name: 'Erdgeschoss', aussen: 0, oberirdisch: true }); z.quellen.push('In den Grundrissen wurden keine Raumflächen gefunden. Bitte die Fläche hier von Hand eintragen.'); }
    z.floors.forEach(f => box.append(geschossZeile(f)));
    $('gzQuelle').textContent = z.quellen.join('  ');
    $('gzEditTitel').textContent = w === 'hand' ? 'Eure Eingaben' : 'Flächen aus dem Plan';
    const noten = ['gzTerrNote', 'gzGarNote', 'gzNebNote', 'gzTiefNote', 'gzZufNote'];
    if (z.manuell) {
      const m = z.manuell;
      $('gzTerr').value = deKurz(m.terrasse); $('gzGar').value = deKurz(m.garage); $('gzZuf').value = deKurz(m.zufahrt); $('gzNeb').value = deKurz(m.nebenanlage); $('gzTief').value = deKurz(m.tiefgarage); $('gzUeber').value = deKurz(m.ueber);
      noten.forEach(id => { $(id).textContent = ''; });
      return;
    }
    const summe = a => z.extras[a].reduce((s, r) => s + r.flaeche, 0);
    const setze = (id, art, noteId, ohne) => {
      $(id).value = deKurz(Math.round(summe(art) * 100) / 100);
      $(noteId).textContent = z.extras[art].length ? 'Aus dem Plan: ' + z.extras[art].map(r => `${r.name} ${de(r.flaeche)} m²`).join(', ') + '. Bitte prüfen.' : (ohne || '');
    };
    setze('gzTerr', 'terrasse', 'gzTerrNote'); setze('gzGar', 'garage', 'gzGarNote'); setze('gzNeb', 'nebenanlage', 'gzNebNote'); setze('gzTief', 'tiefgarage', 'gzTiefNote');
    setze('gzZuf', 'zufahrt', 'gzZufNote', 'Steht meist nur im Lageplan (zum Beispiel "Befestigte Fläche"), bitte eintragen.');
    $('gzUeber').value = '0';
  }  function geschossZeile(f) {
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
  let animiere = false;   // nur beim ersten Zeigen nach dem Start: Zahlen laufen ein, das Raster füllt sich
  const reduziert = !!(window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches);

  function neuRechnen() {
    if ($('gzErgebnis').classList.contains('versteckt')) return;
    const e = lies();
    $('gzUeberFeld').classList.toggle('versteckt', e.fassung !== 1990);
    const res = rechne(e);
    if (!res) { $('gzKarteI').textContent = 'Bitte Grundstücksgröße und BauNVO-Fassung eintragen.'; $('gzKarteII').textContent = ''; return; }
    const wenn = aktualisiereWenn(e);
    const resW = wenn.aktiv ? rechne(wenn.eW) : res;
    zeichne(e, res, resW, wenn.aktiv);
    animiere = false;
  }

  // ---- Bausteine "Was wäre, wenn"
  const BAUSTEINE = [
    { key: 'anbau', name: 'Anbau am Haus', hilfe: 'vergrößert die Gebäudegrundfläche' },
    { key: 'garage', name: 'Carport oder Garage', hilfe: 'Garagen und überdachte Stellplätze' },
    { key: 'terrasse', name: 'Terrasse oder Balkon', hilfe: 'Terrassen, Balkone, Loggien' },
    { key: 'neben', name: 'Gartenhaus oder Nebenanlage', hilfe: 'Gartenhaus, Schuppen, Pool' }
  ];
  const wennZeilen = {};
  BAUSTEINE.forEach(b => {
    const z = el('div', 'gz-wenn-zeile');
    z.innerHTML = `<div class="gz-wenn-name"></div><input type="range" min="0" max="50" step="0.5" value="0"><div class="gz-eing gz-wenn-zahl"><input type="text" inputmode="decimal" value="0"><i>m²</i></div><button type="button" class="gz-wenn-max" title="Auf die größte Fläche stellen, die noch passt">bis zur Grenze</button><div class="gz-wenn-info"></div>`;
    z.querySelector('.gz-wenn-name').append(el('b', '', b.name), el('small', '', b.hilfe));
    const reg = z.querySelector('input[type=range]'), num = z.querySelector('.gz-wenn-zahl input');
    z.dataset.wert = '0';   // genauer Wert (der Regler rastet nur in 0,5-Schritten ein)
    reg.addEventListener('input', () => { z.dataset.wert = reg.value; num.value = deKurz(+reg.value); neuRechnen(); });
    num.addEventListener('input', () => { const v = Math.max(0, zahl(num.value) || 0); z.dataset.wert = String(v); reg.value = String(v); neuRechnen(); });
    z.querySelector('.gz-wenn-max').addEventListener('click', () => { const m = +z.dataset.moeglich || 0; const v = Math.floor(m * 100) / 100; reg.max = String(Math.max(+reg.max, Math.ceil(v))); reg.value = String(v); z.dataset.wert = String(v); num.value = deKurz(v); neuRechnen(); });
    wennZeilen[b.key] = { z, reg, num, info: z.querySelector('.gz-wenn-info') };
    $('gzWennZeilen').append(z);
  });
  $('gzWennReset').addEventListener('click', () => { BAUSTEINE.forEach(b => { const w = wennZeilen[b.key]; w.reg.value = '0'; w.num.value = '0'; w.z.dataset.wert = '0'; }); neuRechnen(); });
  const wennWerte = () => Object.fromEntries(BAUSTEINE.map(b => [b.key, Math.max(0, +wennZeilen[b.key].z.dataset.wert || 0)]));
  const szenario = (e, v) => ({ ...e, anbau: v.anbau, terrassen: e.terrassen + v.terrasse, garagen: e.garagen + v.garage, nebenanlagen: e.nebenanlagen + v.neben });
  const passt = r => r.I.ok && r.II.ok;
  // Größte Fläche eines Bausteins, die (mit den anderen Reglern wie eingestellt) noch alles einhält
  function moeglich(e, v, key) {
    const mit = x => rechne(szenario(e, { ...v, [key]: x }));
    if (!passt(mit(0))) return 0;
    let lo = 0, hi = e.G;
    if (passt(mit(hi))) return hi;
    for (let i = 0; i < 40; i++) { const mid = (lo + hi) / 2; if (passt(mit(mid))) lo = mid; else hi = mid; }
    return lo;
  }
  function aktualisiereWenn(e) {
    const v = wennWerte();
    const aktiv = Object.values(v).some(x => x > 0);
    for (const b of BAUSTEINE) {
      const w = wennZeilen[b.key];
      const m = moeglich(e, v, b.key);
      w.z.dataset.moeglich = String(m);
      // Reglerlänge: bis etwas über das, was noch passt (mindestens 10 m², höchstens das Grundstück)
      const max = Math.min(Math.ceil(e.G), Math.max(10, Math.ceil(Math.max(m * 1.5, e.G * 0.1, v[b.key]) / 5) * 5));
      if (+w.reg.max !== max) w.reg.max = String(max);
      const ohne = rechne(szenario(e, { ...v, [b.key]: 0 })), mit = rechne(szenario(e, v));
      const dI = mit.I.ist - ohne.I.ist, dII = mit.II.ist - ohne.II.ist;
      w.info.textContent = '';
      const teile = [];
      if (v[b.key] > 0) teile.push(dI > EPS || dII > EPS ? `Zählt: GRZ I ${dI > EPS ? '+' + de(dI) : '0,00'} m², GRZ II ${dII > EPS ? '+' + de(dII) : '0,00'} m².` : `Zählt nach ${FASSUNG_NAME[e.fassung]} nicht auf die GRZ.`);
      teile.push(m > 0.05 ? `Noch möglich: bis zu ${de(m)} m².` : 'Hier passt nichts mehr dazu.');
      w.info.textContent = teile.join(' ');
      w.z.querySelector('.gz-wenn-max').disabled = m < 0.1;
    }
    return { aktiv, v, eW: szenario(e, v) };
  }

  // ---- Bausteine der Anzeige
  function balken(ist, zul, titel, plus) {
    plus = Math.max(0, plus || 0);
    const total = Math.max(ist + plus, zul) * 1.1 || 1;
    const b = el('div', 'gz-balken'); b.setAttribute('role', 'img'); b.setAttribute('aria-label', `${titel}: ${de(ist)} von ${de(zul)} Quadratmetern` + (plus ? `, mit Änderung ${de(ist + plus)}` : ''));
    const prozent = x => (x / total * 100) + '%';
    const f = el('div', 'gz-fuell'); b.append(f);
    const bisZul = Math.min(ist, zul);
    const setzen = () => { f.style.width = prozent(bisZul); };
    if (animiere && !reduziert) { f.style.width = '0'; setTimeout(setzen, 40); } else setzen();
    if (plus > EPS && ist < zul) { const p = el('div', 'gz-plus'); p.style.left = prozent(ist); p.style.width = prozent(Math.min(plus, zul - ist)); b.append(p); }
    const ueberStart = Math.max(ist, zul), ueberEnde = ist + plus;
    if (ueberEnde > zul + EPS) { const u = el('div', 'gz-ueber'); u.style.left = prozent(Math.min(zul, ueberStart)); u.style.width = prozent(ueberEnde - Math.min(zul, ueberStart)); b.append(u); }
    const m = el('div', 'gz-marke'); m.style.left = prozent(zul); m.append(el('span', '', 'zulässig')); b.append(m);
    return b;
  }
  // Zahl, die ruhig hochzählt (nur beim ersten Zeigen)
  function zaehle(knoten, ziel) {
    const endtext = de(ziel) + ' m²';
    if (!animiere || reduziert) { knoten.textContent = endtext; return; }
    knoten.textContent = de(0) + ' m²';
    const t0 = performance.now(), dauer = 900;
    const schritt = t => { const p = Math.min(1, (t - t0) / dauer); knoten.textContent = de(ziel * (1 - Math.pow(1 - p, 3))) + ' m²'; if (p < 1) requestAnimationFrame(schritt); };
    requestAnimationFrame(schritt);
    setTimeout(() => { knoten.textContent = endtext; }, dauer + 150);
  }
  function zahlenZeile(items) {
    const z = el('div', 'gz-zahlen' + (items.length === 4 ? ' vier' : ''));
    items.forEach(([titel, ziel, klasse]) => { const k = el('div', 'gz-zahl' + (klasse ? ' ' + klasse : '')); const b = el('b', '', ''); zaehle(b, ziel); k.append(el('small', '', titel), b); z.append(k); });
    return z;
  }
  function schild(ok, text) { return el('span', 'gz-schild ' + (ok ? 'ok' : 'ueber'), (ok ? '✓ ' : '! ') + text); }
  // kleines (i) mit Erklärung in einfacher Sprache
  function infoKnopf(text, ziel) {
    const b = el('button', 'gz-info', 'i'); b.type = 'button'; b.setAttribute('aria-expanded', 'false'); b.setAttribute('aria-label', 'Erklärung anzeigen'); b.title = 'Erklärung';
    b.addEventListener('click', ev => { ev.stopPropagation(); const auf = ziel.classList.toggle('auf'); b.setAttribute('aria-expanded', auf ? 'true' : 'false'); b.classList.toggle('an', auf); });
    return b;
  }

  // Grundstück als 10 mal 10 Kästchen: segmente = [[Art, m², Text], ...] in dieser Reihenfolge, der Rest ist übriges Grundstück
  function raster(G, segmente) {
    const wrap = el('div', 'gz-raster-zeile');
    const r = el('div', 'gz-raster' + (animiere && !reduziert ? ' ein' : '')); r.setAttribute('aria-hidden', 'true');
    let rest = 100, nr = 0;
    const leg = el('div', 'gz-legende');
    const zelle = art => { const i = el('i', 'gz-c-' + art); if (animiere && !reduziert) i.style.animationDelay = (nr * 9) + 'ms'; nr++; r.append(i); };
    for (const [art, m2, text] of segmente) {
      if (!(m2 > EPS)) continue;
      const n = Math.min(rest, Math.max(1, Math.round(m2 / G * 100))); rest -= n;
      for (let i = 0; i < n; i++) zelle(art);
      const z = el('div', 'gz-leg'); z.append(el('i', 'gz-c-' + art), el('span', '', `${text}: ${de(m2)} m²`)); leg.append(z);
    }
    for (let i = 0; i < rest; i++) zelle('rest');
    wrap.append(r, leg);
    return wrap;
  }

  // s = Ist, sW = mit Änderung (gleich s, wenn kein Baustein gewählt ist)
  function karte(box, titel, untertitel, erklaerung, s, sW, G, segmente, wort, aktiv) {
    box.textContent = '';
    const kopf = el('div', 'gz-karte-kopf'); const h = el('h3', '', titel);
    const erkl = el('p', 'gz-erkl', erklaerung);
    h.append(infoKnopf(erklaerung, erkl));
    kopf.append(h, schild(sW.ok, (sW.ok ? 'eingehalten' : 'überschritten') + (aktiv ? ' mit Änderung' : '')));
    box.append(kopf, erkl, el('div', 'gz-stufe', untertitel));
    const rest = [sW.ok ? 'noch frei' : 'zu viel', sW.ok ? sW.frei : sW.ueber, sW.ok ? 'frei' : 'stark'];
    box.append(zahlenZeile(aktiv
      ? [['bebaut (Ist)', s.ist], ['mit Änderung', sW.ist, 'plus'], ['zulässig (GRZ ' + deKurz(Math.round(s.wertZul * 1000) / 1000) + ')', s.zul], rest]
      : [['bebaut (Ist)', s.ist], ['zulässig (GRZ ' + deKurz(Math.round(s.wertZul * 1000) / 1000) + ')', s.zul], rest]));
    box.append(balken(s.ist, s.zul, titel, sW.ist - s.ist));
    const r = aktiv ? sW : s;
    box.append(el('p', 'gz-ist', `${aktiv ? 'Mit Änderung' : 'Ist-Zustand'}: ${wort} ${deKurz(Math.round(r.wert * 1000) / 1000)}, erlaubt ${deKurz(Math.round(r.wertZul * 1000) / 1000)}. ` +
      (r.ok ? `Innerhalb der Vorgabe bleiben noch ${de(r.frei)} m² (${de(r.frei / G * 100, 1)} % des Grundstücks).` : `Die Vorgabe ist um ${de(r.ueber)} m² überschritten.`)));
    box.append(raster(G, segmente));
  }

  // Ein Satz zum Ergebnis, sachlich
  function titelsatz(r, G, aktiv) {
    const pre = aktiv ? 'Mit der Änderung: ' : '';
    const proz = x => de(x / G * 100, 1);
    const I = r.I, II = r.II;
    if (I.ok && II.ok) return `${pre}Die GRZ ist eingehalten. In der GRZ I bleiben noch ${de(I.frei)} m² (${proz(I.frei)} % des Grundstücks) frei, in der GRZ II noch ${de(II.frei)} m².`;
    if (!I.ok && II.ok) return `${pre}Die GRZ I ist um ${de(I.ueber)} m² überschritten. Die GRZ II ist eingehalten, dort bleiben noch ${de(II.frei)} m² frei.`;
    if (I.ok && !II.ok) return `${pre}Die GRZ I ist eingehalten (noch ${de(I.frei)} m² frei), die GRZ II ist um ${de(II.ueber)} m² überschritten.`;
    return `${pre}Beide Grenzen sind überschritten: die GRZ I um ${de(I.ueber)} m², die GRZ II um ${de(II.ueber)} m².`;
  }

  function zeichne(e, res, resW, aktiv) {
    const G = res.G;
    $('gzTitel').textContent = `Grundstück ${de(G, 0)} m² · ${FASSUNG_NAME[e.fassung]} · GRZ ${deKurz(e.grz)}`;
    $('gzTitelsatz').textContent = titelsatz(resW, G, aktiv);
    const chips = $('gzChips'); chips.textContent = '';
    const zus = aktiv ? ' mit Änderung' : '';
    chips.append(schild(resW.I.ok, 'GRZ I ' + (resW.I.ok ? 'eingehalten' : 'überschritten') + zus), schild(resW.II.ok, 'GRZ II ' + (resW.II.ok ? 'eingehalten' : 'überschritten') + zus));
    const terr = res.posten.filter(p => p.stufe === 1 && p.name.startsWith('Balkone')).reduce((s, p) => s + p.angerechnet, 0);
    const geb = Math.min(res.gebaeude, G);
    const gebSeg = ['geb', geb, 'Gebäude'], terrSeg = ['terr', terr, 'Terrassen und Balkone (angerechnet)'];
    const dI = Math.max(0, resW.I.ist - res.I.ist), dII = Math.max(0, resW.II.ist - res.II.ist);
    const infoI = 'Die GRZ I betrachtet nur die Hauptanlagen, also das Haus' + (e.fassung === 1968 ? '' : ' samt Terrassen und Balkonen') + '. Sie darf die GRZ aus dem Bebauungsplan nicht überschreiten.';
    const infoII = e.fassung === 1990 ? 'Die GRZ II zählt zur GRZ I noch Garagen, Stellplätze mit Zufahrten, Nebenanlagen und Unterbauung dazu. Die GRZ darf dafür um 50 % überschritten werden, höchstens bis 0,8.'
      : e.fassung === 1968 ? 'Die GRZ II zählt zur GRZ I die Garagen und überdachten Stellplätze dazu. Die Grenze darf um ein Zehntel des Grundstücks höher liegen (§ 21a).'
      : 'Die GRZ II prüft zusätzlich die Garagen und überdachten Stellplätze: Bis zu einem Zehntel des Grundstücks zählen sie nicht, darüber ganz (§ 19 Abs. 5).';
    karte($('gzKarteI'), 'GRZ I', 'Hauptanlagen: ' + (e.fassung === 1968 ? 'Gebäude (Terrassen und Balkone zählen hier nicht)' : 'Gebäude samt Terrassen und Balkonen'), infoI, res.I, resW.I, G,
      [gebSeg, terrSeg, ['plus', dI, 'Änderung (Was wäre, wenn)'], ['frei', resW.I.frei, 'noch frei bis zur Grenze']], 'GRZ I', aktiv);
    karte($('gzKarteII'), 'GRZ II', res.II.beschreibung, infoII, res.II, resW.II, G,
      [gebSeg, terrSeg, ['weit', Math.max(0, res.II.extra), 'weitere angerechnete Flächen'], ['plus', dII, 'Änderung (Was wäre, wenn)'], ['frei', resW.II.frei, 'noch frei bis zur Grenze']], 'GRZ II', aktiv);
    wie(e, res);
  }

  const offeneInfos = new Set();
  function wie(e, res) {
    const box = $('gzWie'); box.textContent = '';
    [[1, 'GRZ I: Hauptanlagen'], [2, 'GRZ II: weitere Anlagen']].forEach(([st, titel]) => {
      const b = el('div', 'gz-wie-block'); b.append(el('h4', '', titel + ' (' + FASSUNG_NAME[e.fassung] + ')'));
      res.posten.filter(p => p.stufe === st).forEach(p => {
        const z = el('div', 'gz-wie-zeile' + (p.zaehlt ? ' ja' : ''));
        const detail = el('div', 'gz-wie-detail', p.einfach);
        const schluessel = st + ':' + p.name;
        if (offeneInfos.has(schluessel)) detail.classList.add('auf');
        const name = el('span', 'gz-wie-name', p.name);
        const ik = infoKnopf(p.einfach, detail); if (offeneInfos.has(schluessel)) { ik.classList.add('an'); ik.setAttribute('aria-expanded', 'true'); }
        ik.addEventListener('click', () => { if (detail.classList.contains('auf')) offeneInfos.add(schluessel); else offeneInfos.delete(schluessel); });
        name.append(ik);
        z.append(el('span', 'gz-wie-zeichen', p.zaehlt ? '✓' : '–'), name, el('span', 'gz-wie-zahl', p.angerechnet === p.flaeche || !p.flaeche ? de(p.flaeche) + ' m²' : de(p.flaeche) + ' m², angerechnet ' + de(p.angerechnet) + ' m²'), el('span', 'gz-wie-grund', p.grund));
        b.append(z, detail);
      });
      box.append(b);
    });
    const h = $('gzHinweise'); h.textContent = '';
    res.hinweise.forEach(t => h.append(el('div', 'gz-meldung', t)));
  }

  pruefeBereit();
})();