import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class Estacion {
  final String name;
  final String latitude;
  final String longitude;

  Estacion({required this.name, required this.latitude, required this.longitude});

  factory Estacion.fromJson(Map<String, dynamic> json) {
    return Estacion(
      name: json['name'],
      latitude: json['field_latitud'],
      longitude: json['field_longitud'],
    );
  }

  String generateTitle(int unixTime) {
    return '${this.name}_${unixTime.toString()}';
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evaluar Taquillas',
      theme: ThemeData(
        primaryColor: Colors.orange,
        scaffoldBackgroundColor: Colors.orangeAccent,
        textTheme: const TextTheme(
          bodyText2: TextStyle(color: Colors.black),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
      ),
      home: const QueueForm(),
    );
  }
}

class QueueForm extends StatefulWidget {
  const QueueForm({Key? key});

  @override
  _QueueFormState createState() => _QueueFormState();
}

class _QueueFormState extends State<QueueForm> {
  final TextEditingController _evaluatorController = TextEditingController();
  final List<Estacion> _estaciones = [];
  Estacion? _selectedEstacion;
  String? _selectedTicket;

  bool _formEnabled = true;
  late DateTime _startQueueTime;
  late Duration _elapsedTime = Duration.zero;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _fetchEstaciones();
  }

  Future<void> _fetchEstaciones() async {
    final response = await http.get(Uri.parse('http://24.199.103.244:8051/taquillas'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _estaciones.addAll(data.map((estacion) => Estacion.fromJson(estacion)).toList());
      });
    } else {
      throw Exception('Failed to load estaciones');
    }
  }

  @override
  void dispose() {
    _evaluatorController.dispose();
    super.dispose();
  }

  void _startQueue() {
    if (_evaluatorController.text.isEmpty || _selectedEstacion == null || _selectedTicket == null) {
      return;
    }

    setState(() {
      _formEnabled = false;
      _startQueueTime = DateTime.now();
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startQueueTime);
        });
      });
    });
  }

  void _stopQueue() {
    setState(() {
      _timer.cancel();
      _formEnabled = true;
    });
    _sendQueueData();
  }

  void _sendQueueData() {
    String evaluator = _evaluatorController.text;
    String stationName = _selectedEstacion!.name;
    String latitude = _selectedEstacion!.latitude;
    String longitude = _selectedEstacion!.longitude;
    String ticket = _selectedTicket!;
    int unixTime = DateTime.now().millisecondsSinceEpoch;

    // Generar el título y el tipo de evaluación
    String title = _selectedEstacion!.generateTitle(unixTime);
    String type = 'evaluacion_de_servicio';

    // Define la estructura de los datos que se enviarán al servidor
    Map<String, dynamic> requestData = {
      'title': [{'value': title}],
      'type': [{'target_id': type}],
      'field_taquilla': [{'value': stationName}],
      'field_duracion_intervalo': [{'value': _elapsedTime.inSeconds}],
      'field_estacion': [{'value': stationName}],
      'field_fin_del_intervalo': [{'value': DateTime.now().toIso8601String()}],
      'field_identificacion_evaluador': [{'value': evaluator}],
      'field_inicio_del_intervalo': [{'value': _startQueueTime.toIso8601String()}],
    };

    // Envía los datos al servidor
    _postData(requestData);
  }

  Future<void> _postData(Map<String, dynamic> data) async {
    final url = Uri.parse('http://24.199.103.244:8051/tuservicio');
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      print('Datos enviados con éxito.');
    } else {
      print('Error al enviar los datos: ${response.statusCode}');
    }
  }

  void _resetForm() {
    setState(() {
      _evaluatorController.clear();
      _formEnabled = true;
      _elapsedTime = Duration.zero;
      _selectedEstacion = null;
      _selectedTicket = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Form'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _evaluatorController,
                enabled: _formEnabled,
                decoration: const InputDecoration(
                  labelText: 'Evaluador',
                ),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<Estacion>(
                items: _estaciones.map((estacion) {
                  return DropdownMenuItem<Estacion>(
                    value: estacion,
                    child: Text(estacion.name),
                  );
                }).toList(),
                onChanged: _formEnabled ? (value) => setState(() => _selectedEstacion = value) : null,
                value: _selectedEstacion,
                decoration: const InputDecoration(
                  labelText: 'Estación',
                ),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                items: ['Taquilla A', 'Taquilla B']
                    .map((ticket) => DropdownMenuItem<String>(
                  value: ticket,
                  child: Text(ticket),
                ))
                    .toList(),
                onChanged: _formEnabled ? (value) => setState(() => _selectedTicket = value) : null,
                value: _selectedTicket,
                decoration: const InputDecoration(
                  labelText: 'Ticket',
                ),
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _formEnabled ? _startQueue : null,
                child: const Text('Start Queue', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _formEnabled ? null : _stopQueue,
                child: const Text('Stop Queue', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              // Mostrar el tiempo transcurrido
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Time Elapsed: ${_elapsedTime.inHours}:${(_elapsedTime.inMinutes % 60).toString().padLeft(2, '0')}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _resetForm,
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
