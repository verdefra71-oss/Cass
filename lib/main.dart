import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

String dataIt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String meseIt(DateTime d) {
  const mesi = [
    'GENNAIO', 'FEBBRAIO', 'MARZO', 'APRILE', 'MAGGIO', 'GIUGNO',
    'LUGLIO', 'AGOSTO', 'SETTEMBRE', 'OTTOBRE', 'NOVEMBRE', 'DICEMBRE'
  ];
  return '${mesi[d.month - 1]} ${d.year}';
}


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GestioneFamiliareApp());
}

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
    id: j['id'], data: DateTime.parse(j['data']), entrata: j['entrata'],
    categoria: j['categoria'], descrizione: j['descrizione'] ?? '',
    importo: (j['importo'] as num).toDouble(), metodo: j['metodo'],
  );
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
      final caricati = decoded
          .map((e) => Movimento.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        movimenti = caricati;
        _caricato = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _caricato = true);
    }
  }

  Future<void> _salva() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'movimenti',
      jsonEncode(movimenti.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _aggiungi(Movimento m) async {
    setState(() => movimenti.add(m));
    await _salva();
  }

  Future<void> _elimina(String id) async {
    setState(() => movimenti.removeWhere((m) => m.id == id));
    await _salva();
  }

  Future<void> _modifica(Movimento nuovo) async {
    final i = movimenti.indexWhere((m) => m.id == nuovo.id);
    if (i >= 0) {
      setState(() => movimenti[i] = nuovo);
      await _salva();
    }
  }

  Future<void> _esporta() async {
    final dati = jsonEncode({
      'app': 'Gestione Familiare',
      'versione': 1,
      'movimenti': movimenti.map((e) => e.toJson()).toList(),
    });
    final nome = 'gestione_familiare_backup_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.json';
    await Share.shareXFiles(
      [XFile.fromData(Uint8List.fromList(utf8.encode(dati)), name: nome, mimeType: 'application/json')],
      text: 'Backup dati Gestione Familiare',
    );
  }

  Future<void> _importa() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    try {
      final testo = utf8.decode(result.files.single.bytes!);
      final dati = jsonDecode(testo) as Map<String, dynamic>;
      final lista = (dati['movimenti'] as List<dynamic>? ?? [])
          .map((e) => Movimento.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() => movimenti = lista);
      await _salva();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Importati ${lista.length} movimenti.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File di backup non valido.')),
      );
    }
  }

  @override Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestione Familiare',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xfff7f7f7),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6)),
      ),
      home: !_caricato
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : HomePage(
              movimenti: movimenti,
              onAdd: _aggiungi,
              onDelete: _elimina,
              onEdit: _modifica,
              onExport: _esporta,
              onImport: _importa,
            ),
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
  const HomePage({super.key, required this.movimenti, required this.onAdd, required this.onDelete, required this.onEdit, required this.onExport, required this.onImport});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime mese = DateTime(DateTime.now().year, DateTime.now().month);

  List<Movimento> get delMese => widget.movimenti.where((m) =>
    m.data.year == mese.year && m.data.month == mese.month).toList()
    ..sort((a,b) => b.data.compareTo(a.data));

  double totale(bool entrata, String metodo) =>
    delMese.where((m) => m.entrata == entrata && m.metodo == metodo)
      .fold(0, (s,m) => s + m.importo);

  double get saldo => delMese.fold(0, (s,m) => s + (m.entrata ? m.importo : -m.importo));

  String euro(double n) => '${n.toStringAsFixed(2).replaceAll('.', ',')} €';

  Future<void> _nuovo({bool entrata = true}) async {
    final m = await Navigator.push<Movimento>(context, MaterialPageRoute(
      builder: (_) => MovimentoPage(entrata: entrata)));
    if (m != null) widget.onAdd(m);
  }

  Future<void> _edit(Movimento old) async {
    final m = await Navigator.push<Movimento>(context, MaterialPageRoute(
      builder: (_) => MovimentoPage(entrata: old.entrata, movimento: old)));
    if (m != null) widget.onEdit(m);
  }

  @override Widget build(BuildContext context) {
    final contanti = totale(true,'Contanti') - totale(false,'Contanti');
    final banca = totale(true,'Banca') - totale(false,'Banca');
    return Scaffold(
      appBar: AppBar(title: const Text('Gestione Familiare'), actions: [
        PopupMenuButton<String>(
          tooltip: 'Dati',
          onSelected: (v) {
            if (v == 'export') widget.onExport();
            if (v == 'import') widget.onImport();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'export', child: Text('Esporta dati')),
            PopupMenuItem(value: 'import', child: Text('Importa dati')),
          ],
        ),
        IconButton(onPressed: () async {
          final m = await showDatePicker(context: context, initialDate: mese,
            firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (m != null) setState(() => mese = DateTime(m.year,m.month));
        }, icon: const Icon(Icons.calendar_month))
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(onPressed: () => setState(() => mese=DateTime(mese.year,mese.month-1)), icon: const Icon(Icons.chevron_left)),
            Text(meseIt(mese),
              style: const TextStyle(fontSize:18,fontWeight:FontWeight.w600)),
            IconButton(onPressed: () => setState(() => mese=DateTime(mese.year,mese.month+1)), icon: const Icon(Icons.chevron_right)),
          ],
        )),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          const Text('SALDO DEL MESE', style: TextStyle(fontSize:13,letterSpacing:1)),
          const SizedBox(height:6),
          Text(euro(saldo), style: TextStyle(fontSize:30,fontWeight:FontWeight.bold,
            color: saldo >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
          const SizedBox(height:14),
          Row(mainAxisAlignment:MainAxisAlignment.spaceAround, children:[
            _saldoBox('Contanti',contanti),
            _saldoBox('Banca',banca),
          ])
        ]))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 4), child: Row(children:[
          Expanded(child: FilledButton.icon(onPressed:()=>_nuovo(entrata:true),
            icon:const Icon(Icons.add),label:const Text('Entrata'))),
          const SizedBox(width:10),
          Expanded(child: OutlinedButton.icon(onPressed:()=>_nuovo(entrata:false),
            icon:const Icon(Icons.remove),label:const Text('Uscita'))),
        ])),
        const Padding(padding: EdgeInsets.fromLTRB(16,8,16,4), child: Align(
          alignment: Alignment.centerLeft, child: Text('Movimenti',style:TextStyle(fontSize:18,fontWeight:FontWeight.w600)))),
        Expanded(child: delMese.isEmpty
          ? const Center(child: Text('Nessun movimento per questo mese.'))
          : ListView.builder(itemCount:delMese.length,itemBuilder:(c,i){
            final m=delMese[i];
            return Dismissible(key:ValueKey(m.id),background:Container(color:Colors.red,alignment:Alignment.centerLeft,padding:const EdgeInsets.only(left:20),child:const Icon(Icons.delete,color:Colors.white)),
              secondaryBackground:Container(color:Colors.red,alignment:Alignment.centerRight,padding:const EdgeInsets.only(right:20),child:const Icon(Icons.delete,color:Colors.white)),
              onDismissed:(_)=>widget.onDelete(m.id),
              child: Card(child: ListTile(onTap:()=>_edit(m),
                leading:CircleAvatar(child:Icon(m.entrata?Icons.arrow_downward:Icons.arrow_upward)),
                title:Text(m.categoria,style:const TextStyle(fontWeight:FontWeight.w600)),
                subtitle:Text('${dataIt(m.data)} • ${m.metodo}${m.descrizione.isEmpty?'':' • ${m.descrizione}'}'),
                trailing:Text('${m.entrata?'+':'-'} ${euro(m.importo)}',style:TextStyle(fontWeight:FontWeight.bold,color:m.entrata?Colors.green.shade700:Colors.red.shade700)),
              )));
          }))
      ]),
    );
  }

  Widget _saldoBox(String label,double value)=>Column(children:[
    Text(label,style:const TextStyle(fontWeight:FontWeight.w500)),
    const SizedBox(height:3),Text(euro(value),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))
  ]);
}

class MovimentoPage extends StatefulWidget {
  final bool entrata;
  final Movimento? movimento;
  const MovimentoPage({super.key,required this.entrata,this.movimento});
  @override State<MovimentoPage> createState()=>_MovimentoPageState();
}

class _MovimentoPageState extends State<MovimentoPage>{
  late bool entrata;
  late DateTime data;
  late String categoria;
  late String metodo;
  final descrizione=TextEditingController();
  final importo=TextEditingController();

  static const entrate=['Stipendio','Banca','Extra'];
  static const uscite=['Acqua','Luce','Gas','Internet','Benzina','Bollo auto','Assicurazione','Condominio','Altre'];

  @override void initState(){
    super.initState();
    final m=widget.movimento;
    entrata=m?.entrata??widget.entrata; data=m?.data??DateTime.now();
    categoria=m?.categoria??(widget.entrata?entrate.first:uscite.first);
    metodo=m?.metodo??'Contanti';
    descrizione.text=m?.descrizione??'';
    importo.text=m==null?'':m.importo.toStringAsFixed(2);
  }

  @override void dispose(){descrizione.dispose();importo.dispose();super.dispose();}

  Future<void> _data() async {
    final d=await showDatePicker(context:context,initialDate:data,firstDate:DateTime(2020),lastDate:DateTime(2100));
    if(d!=null)setState(()=>data=d);
  }

  void _salva(){
    final v=double.tryParse(importo.text.replaceAll(',','.'));
    if(v==null||v<=0){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Inserisci un importo valido.')));
      return;
    }
    Navigator.pop(context,Movimento(
      id:widget.movimento?.id??DateTime.now().microsecondsSinceEpoch.toString(),
      data:data,entrata:entrata,categoria:categoria,descrizione:descrizione.text.trim(),
      importo:v,metodo:metodo));
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(title:Text(widget.movimento==null?(entrata?'Nuova entrata':'Nuova uscita'):'Modifica movimento')),
      body:ListView(padding:const EdgeInsets.all(18),children:[
        SegmentedButton<bool>(segments:const[
          ButtonSegment(value:true,label:Text('Entrata'),icon:Icon(Icons.add)),
          ButtonSegment(value:false,label:Text('Uscita'),icon:Icon(Icons.remove))],
          selected:{entrata},onSelectionChanged:(s)=>setState(() { entrata=s.first; categoria=(s.first?entrate:uscite).first; }),
        ),
        const SizedBox(height:18),
        ListTile(contentPadding:EdgeInsets.zero,title:const Text('Data'),subtitle:Text(dataIt(data)),
          trailing:IconButton(onPressed:_data,icon:const Icon(Icons.calendar_today))),
        DropdownButtonFormField<String>(initialValue:categoria,decoration:const InputDecoration(labelText:'Categoria',border:OutlineInputBorder()),
          items:(entrata?entrate:uscite).map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
          onChanged:(v){if(v!=null)setState(()=>categoria=v);}),
        const SizedBox(height:14),
        DropdownButtonFormField<String>(initialValue:metodo,decoration:const InputDecoration(labelText:'Metodo',border:OutlineInputBorder()),
          items:['Contanti','Banca'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
          onChanged:(v){if(v!=null)setState(()=>metodo=v);}),
        const SizedBox(height:14),
        TextField(controller:descrizione,decoration:const InputDecoration(labelText:'Descrizione (facoltativa)',border:OutlineInputBorder())),
        const SizedBox(height:14),
        TextField(controller:importo,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:const InputDecoration(labelText:'Importo €',border:OutlineInputBorder())),
        const SizedBox(height:24),
        FilledButton(onPressed:_salva,child:const Padding(padding:EdgeInsets.all(12),child:Text('SALVA'))),
      ])
    );
  }
}
