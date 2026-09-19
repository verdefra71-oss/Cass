import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

String dataIt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String meseIt(DateTime d) {
  const mesi = ['GENNAIO','FEBBRAIO','MARZO','APRILE','MAGGIO','GIUGNO',
    'LUGLIO','AGOSTO','SETTEMBRE','OTTOBRE','NOVEMBRE','DICEMBRE'];
  return '${mesi[d.month - 1]} ${d.year}';
}

String euro(double n) =>
    '${n.toStringAsFixed(2).replaceAll('.', ',')} €';

class Movimento {
  final String id;
  final DateTime data;
  final bool entrata;
  final String categoria;
  final String descrizione;
  final double importo;
  final String metodo;

  Movimento({
    required this.id,
    required this.data,
    required this.entrata,
    required this.categoria,
    required this.descrizione,
    required this.importo,
    required this.metodo,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'data': data.toIso8601String(), 'entrata': entrata,
    'categoria': categoria, 'descrizione': descrizione,
    'importo': importo, 'metodo': metodo,
  };

  factory Movimento.fromJson(Map<String, dynamic> j) => Movimento(
    id: j['id'].toString(),
    data: DateTime.parse(j['data'].toString()),
    entrata: j['entrata'] == true,
    categoria: (j['categoria'] ?? 'Altre').toString(),
    descrizione: (j['descrizione'] ?? '').toString(),
    importo: (j['importo'] as num).toDouble(),
    metodo: (j['metodo'] ?? 'Contanti').toString(),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GestioneFamiliareApp());
}

class GestioneFamiliareApp extends StatefulWidget {
  const GestioneFamiliareApp({super.key});
  @override State<GestioneFamiliareApp> createState() => _AppState();
}

class _AppState extends State<GestioneFamiliareApp> {
  List<Movimento> movimenti = [];
  bool _caricato = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('movimenti') ?? '[]';
      final decoded = jsonDecode(raw) as List<dynamic>;
      final caricati = decoded.map((e) =>
        Movimento.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (!mounted) return;
      setState(() { movimenti = caricati; _caricato = true; });
    } catch (_) {
      if (mounted) setState(() => _caricato = true);
    }
  }

  Future<void> _salva() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('movimenti',
      jsonEncode(movimenti.map((e) => e.toJson()).toList()));
  }

  Future<void> _aggiungi(Movimento m) async {
    setState(() => movimenti.add(m));
    await _salva();
  }

  Future<void> _elimina(String id) async {
    setState(() => movimenti.removeWhere((m) => m.id == id));
    await _salva();
  }

  Future<void> _modifica(Movimento m) async {
    final i = movimenti.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      setState(() => movimenti[i] = m);
      await _salva();
    }
  }

  Future<void> _esporta() async {
    final dati = jsonEncode({
      'app': 'Gestione Familiare', 'versione': 2,
      'movimenti': movimenti.map((e) => e.toJson()).toList(),
    });
    final nome = 'gestione_familiare_backup_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.json';
    await Share.shareXFiles([
      XFile.fromData(Uint8List.fromList(utf8.encode(dati)),
        name: nome, mimeType: 'application/json')
    ], text: 'Backup dati Gestione Familiare');
  }

  Future<void> _importa() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    try {
      final testo = utf8.decode(result.files.single.bytes!);
      final dati = jsonDecode(testo) as Map<String, dynamic>;
      final lista = (dati['movimenti'] as List<dynamic>? ?? [])
        .map((e) => Movimento.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
      setState(() => movimenti = lista);
      await _salva();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Importati ${lista.length} movimenti.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File di backup non valido.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xff5b4b9a));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestione Familiare',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xfff4f2f8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, elevation: 0, centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      home: !_caricato
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : HomePage(
          movimenti: movimenti, onAdd: _aggiungi, onDelete: _elimina,
          onEdit: _modifica, onExport: _esporta, onImport: _importa),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<Movimento> movimenti;
  final void Function(Movimento) onAdd;
  final void Function(String) onDelete;
  final void Function(Movimento) onEdit;
  final Future<void> Function() onExport;
  final Future<void> Function() onImport;

  const HomePage({super.key, required this.movimenti, required this.onAdd,
    required this.onDelete, required this.onEdit, required this.onExport,
    required this.onImport});

  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime mese = DateTime(DateTime.now().year, DateTime.now().month);

  List<Movimento> get delMese {
    final list = widget.movimenti.where((m) =>
      m.data.year == mese.year && m.data.month == mese.month).toList();
    list.sort((a, b) => b.data.compareTo(a.data));
    return list;
  }

  List<Movimento> get precedenti => widget.movimenti.where((m) =>
    m.data.year < mese.year ||
    (m.data.year == mese.year && m.data.month < mese.month)).toList();

  double somma(Iterable<Movimento> ms, bool entrata) =>
    ms.where((m) => m.entrata == entrata).fold(0.0, (s, m) => s + m.importo);

  double get entrate => somma(delMese, true);
  double get uscite => somma(delMese, false);
  double get saldoMese => entrate - uscite;

  // Il saldo di chiusura di ogni mese diventa automaticamente il saldo
  // iniziale del mese successivo.
  double get saldoIniziale => somma(precedenti, true) - somma(precedenti, false);
  double get saldoFinale => saldoIniziale + saldoMese;

  double get contanti => widget.movimenti.where((m) => m.metodo == 'Contanti')
      .fold(0.0, (s, m) => s + (m.entrata ? m.importo : -m.importo));
  double get banca => widget.movimenti.where((m) => m.metodo == 'Banca')
      .fold(0.0, (s, m) => s + (m.entrata ? m.importo : -m.importo));

  Map<String, double> categorie(bool entrata) {
    final map = <String, double>{};
    for (final m in delMese.where((m) => m.entrata == entrata)) {
      map[m.categoria] = (map[m.categoria] ?? 0) + m.importo;
    }
    return map;
  }

  Future<void> _nuovo({required bool entrata}) async {
    final m = await Navigator.push<Movimento>(context,
      MaterialPageRoute(builder: (_) => MovimentoPage(entrata: entrata)));
    if (m != null) widget.onAdd(m);
  }

  Future<void> _edit(Movimento old) async {
    final m = await Navigator.push<Movimento>(context,
      MaterialPageRoute(builder: (_) =>
        MovimentoPage(entrata: old.entrata, movimento: old)));
    if (m != null) widget.onEdit(m);
  }

  void _cambiaMese(int delta) =>
    setState(() => mese = DateTime(mese.year, mese.month + delta));

  @override
  Widget build(BuildContext context) {
    final entrateCat = categorie(true);
    final usciteCat = categorie(false);

    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gestione Familiare',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
          Text('Il tuo bilancio, mese dopo mese',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'export') widget.onExport();
              if (v == 'import') widget.onImport();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export',
                child: ListTile(leading: Icon(Icons.upload_file), title: Text('Esporta dati'))),
              PopupMenuItem(value: 'import',
                child: ListTile(leading: Icon(Icons.download), title: Text('Importa dati'))),
            ]),
        ],
      ),
      body: Column(children: [
        _meseBar(),
        Expanded(child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _riepilogo(),
            _azioni(),
            _sezioneCategorie('ENTRATE PER CATEGORIA', entrateCat, true),
            _sezioneCategorie('SPESE PER CATEGORIA', usciteCat, false),
            _movimentiSection(),
          ],
        )),
      ]),
    );
  }

  Widget _meseBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Container(
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(onPressed: () => _cambiaMese(-1),
          icon: const Icon(Icons.chevron_left)),
        Text(meseIt(mese), style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: .4)),
        IconButton(onPressed: () => _cambiaMese(1),
          icon: const Icon(Icons.chevron_right)),
        IconButton(
          tooltip: 'Scegli mese',
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: mese,
              firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => mese = DateTime(d.year, d.month));
          },
          icon: const Icon(Icons.calendar_month)),
      ]),
    ),
  );

  Widget _riepilogo() => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(children: [
        const Align(alignment: Alignment.centerLeft,
          child: Text('SITUAZIONE DEL MESE',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
              letterSpacing: 1.1))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _numeroBox('Saldo iniziale', saldoIniziale,
            Icons.login_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _numeroBox('Saldo finale', saldoFinale,
            Icons.account_balance_wallet_rounded)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _miniBox('Entrate', entrate, Icons.arrow_downward_rounded, true)),
          const SizedBox(width: 10),
          Expanded(child: _miniBox('Spese', uscite, Icons.arrow_upward_rounded, false)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _portafoglio('Contanti', contanti, Icons.payments_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _portafoglio('Banca', banca, Icons.account_balance_outlined)),
        ]),
        const SizedBox(height: 8),
        Text(
          'Il saldo finale di ${meseIt(mese)} viene riportato automaticamente come saldo iniziale del mese successivo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    ),
  );

  Widget _numeroBox(String label, double value, IconData icon) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xfff0edf7), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 19, color: const Color(0xff5b4b9a)),
      const SizedBox(height: 7),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      const SizedBox(height: 2),
      Text(euro(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _miniBox(String label, double value, IconData icon, bool positivo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: positivo ? const Color(0xffeaf7ef) : const Color(0xffffeeee),
      borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      CircleAvatar(radius: 16, child: Icon(icon, size: 17)),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(euro(value), style: const TextStyle(fontWeight: FontWeight.w800)),
      ])),
    ]),
  );

  Widget _portafoglio(String label, double value, IconData icon) => Row(children: [
    Icon(icon, size: 18, color: const Color(0xff5b4b9a)),
    const SizedBox(width: 7),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
    Text(euro(value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
  ]);

  Widget _azioni() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
    child: Row(children: [
      Expanded(child: FilledButton.icon(
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: () => _nuovo(entrata: true),
        icon: const Icon(Icons.add_circle_outline), label: const Text('ENTRATA'))),
      const SizedBox(width: 10),
      Expanded(child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: () => _nuovo(entrata: false),
        icon: const Icon(Icons.remove_circle_outline), label: const Text('SPESA'))),
    ]),
  );

  Widget _sezioneCategorie(String titolo, Map<String,double> dati, bool entrata) {
    final entries = dati.entries.toList()
      ..sort((a,b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 15, 16, 10), child: Column(
        children: [
          Row(children: [
            Icon(entrata ? Icons.trending_up : Icons.pie_chart_outline,
              size: 20, color: const Color(0xff5b4b9a)),
            const SizedBox(width: 8),
            Expanded(child: Text(titolo, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .5))),
            Text(euro(entries.fold(0.0, (s,e) => s + e.value)),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(padding: const EdgeInsets.all(12),
              child: Text('Nessun dato salvato questo mese.',
                style: TextStyle(color: Colors.grey.shade600)))
          else
            ...entries.map((e) => _categoriaRow(e.key, e.value, entrata)),
        ],
      )),
    );
  }

  Widget _categoriaRow(String nome, double valore, bool entrata) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(width: 38, height: 38,
        decoration: BoxDecoration(color: const Color(0xfff0edf7),
          borderRadius: BorderRadius.circular(11)),
        child: Icon(_iconaCategoria(nome), size: 19, color: const Color(0xff5b4b9a))),
      const SizedBox(width: 10),
      Expanded(child: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600))),
      Text('${entrata ? '+' : '-'} ${euro(valore)}',
        style: TextStyle(fontWeight: FontWeight.w800,
          color: entrata ? Colors.green.shade700 : Colors.red.shade700)),
    ]),
  );

  Widget _movimentiSection() => Card(
    child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MOVIMENTI SALVATI', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .5)),
        const SizedBox(height: 6),
        if (delMese.isEmpty)
          const Padding(padding: EdgeInsets.all(14),
            child: Center(child: Text('Nessun movimento per questo mese.')))
        else
          ...delMese.map((m) => Dismissible(
            key: ValueKey(m.id),
            background: _deleteBg(true), secondaryBackground: _deleteBg(false),
            onDismissed: (_) => widget.onDelete(m.id),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => _edit(m),
              leading: CircleAvatar(
                backgroundColor: m.entrata ? const Color(0xffe8f6ed) : const Color(0xffffeeee),
                child: Icon(m.entrata ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 18, color: m.entrata ? Colors.green.shade700 : Colors.red.shade700)),
              title: Text(m.categoria, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${dataIt(m.data)} • ${m.metodo}${m.descrizione.isEmpty ? '' : ' • ${m.descrizione}'}'),
              trailing: Text('${m.entrata ? '+' : '-'} ${euro(m.importo)}',
                style: TextStyle(fontWeight: FontWeight.w800,
                  color: m.entrata ? Colors.green.shade700 : Colors.red.shade700)),
            ),
          )),
      ]),
    ),
  );

  Widget _deleteBg(bool left) => Container(
    color: Colors.red.shade400,
    alignment: left ? Alignment.centerLeft : Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: const Icon(Icons.delete_outline, color: Colors.white));

  IconData _iconaCategoria(String c) {
    switch (c) {
      case 'Stipendio': return Icons.work_outline;
      case 'Banca': return Icons.account_balance;
      case 'Extra': return Icons.add_business;
      case 'Acqua': return Icons.water_drop_outlined;
      case 'Luce': return Icons.lightbulb_outline;
      case 'Gas': return Icons.local_fire_department_outlined;
      case 'Internet': return Icons.wifi;
      case 'Benzina': return Icons.local_gas_station_outlined;
      case 'Bollo auto': return Icons.directions_car_outlined;
      case 'Assicurazione': return Icons.shield_outlined;
      case 'Condominio': return Icons.apartment_outlined;
      default: return Icons.receipt_long_outlined;
    }
  }
}

class MovimentoPage extends StatefulWidget {
  final bool entrata;
  final Movimento? movimento;
  const MovimentoPage({super.key, required this.entrata, this.movimento});
  @override State<MovimentoPage> createState() => _MovimentoPageState();
}

class _MovimentoPageState extends State<MovimentoPage> {
  late bool entrata;
  late DateTime data;
  late String categoria;
  late String metodo;
  final descrizione = TextEditingController();
  final importo = TextEditingController();

  static const entrate = ['Stipendio','Banca','Extra'];
  static const uscite = ['Acqua','Luce','Gas','Internet','Benzina',
    'Bollo auto','Assicurazione','Condominio','Altre'];

  @override
  void initState() {
    super.initState();
    final m = widget.movimento;
    entrata = m?.entrata ?? widget.entrata;
    data = m?.data ?? DateTime.now();
    categoria = m?.categoria ?? (entrata ? entrate.first : uscite.first);
    metodo = m?.metodo ?? 'Contanti';
    descrizione.text = m?.descrizione ?? '';
    importo.text = m == null ? '' : m.importo.toStringAsFixed(2);
  }

  @override void dispose() {
    descrizione.dispose(); importo.dispose(); super.dispose();
  }

  Future<void> _data() async {
    final d = await showDatePicker(context: context, initialDate: data,
      firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => data = d);
  }

  void _salva() {
    final v = double.tryParse(importo.text.replaceAll(',', '.'));
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un importo valido.')));
      return;
    }
    Navigator.pop(context, Movimento(
      id: widget.movimento?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      data: data, entrata: entrata, categoria: categoria,
      descrizione: descrizione.text.trim(), importo: v, metodo: metodo));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.movimento == null
        ? (entrata ? 'Nuova entrata' : 'Nuova spesa')
        : 'Modifica movimento'),
    ),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('Entrata'), icon: Icon(Icons.add)),
          ButtonSegment(value: false, label: Text('Spesa'), icon: Icon(Icons.remove)),
        ],
        selected: {entrata},
        onSelectionChanged: (s) => setState(() {
          entrata = s.first;
          categoria = (entrata ? entrate : uscite).first;
        }),
      ),
      const SizedBox(height: 18),
      ListTile(
        contentPadding: EdgeInsets.zero,
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Data', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(dataIt(data)),
        trailing: IconButton(onPressed: _data, icon: const Icon(Icons.calendar_today))),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: categoria,
        decoration: const InputDecoration(labelText: 'Categoria'),
        items: (entrata ? entrate : uscite)
          .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) { if (v != null) setState(() => categoria = v); }),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: metodo,
        decoration: const InputDecoration(labelText: 'Dove / metodo'),
        items: ['Contanti','Banca'].map((e) =>
          DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) { if (v != null) setState(() => metodo = v); }),
      const SizedBox(height: 14),
      TextField(controller: descrizione,
        decoration: const InputDecoration(labelText: 'Descrizione (facoltativa)')),
      const SizedBox(height: 14),
      TextField(controller: importo,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Importo €')),
      const SizedBox(height: 26),
      FilledButton.icon(
        onPressed: _salva,
        icon: const Icon(Icons.check),
        label: const Padding(padding: EdgeInsets.all(12), child: Text('SALVA MOVIMENTO')),
      ),
    ]),
  );
}
