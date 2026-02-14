import 'dart:io';
import 'dart:math';
import 'package:collection/collection.dart';


import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:csv/csv.dart';

import 'package:moving_average/moving_average.dart';

enum COLUMNS {
  ACEL_X,
  ACEL_Y,
  ACEL_Z,
  TEMP,
  VEL_X,
  VEL_Y,
  VEL_Z,
  ROLL,
  PITCH,
  YAW,
  MAG_X,
  MAG_Y,
  MAG_Z,
  PRESS_AR,
  ALT,
  LONG,
  LAT,
  VEL_GPS,
  ANG,
  HOUR,
  RPM,
  VEL_HALL
}

List<List<String>> CARD_INFO_GROUP = [
  ["ACELERAÇÃO MÁXIMA", "ACELERAÇÃO MÉDIA", "ACELERACAO MÍNIMA", "m/s²"],
  ["VELOCIDADE MÁXIMA", "VELOCIDADE MÉDIA", "VELOCIDADE MÍNIMO", "km/h"],
  ["ROLL MÁXIMO", "ROLL MÉDIO", "ROLL MÍNIMO", "graus"],
  ["PITCH MÁXIMO", "PITCH MÉDIO", "PITCH MÍNIMO", "graus"],
  ["YAW MÁXIMO", "YAW MÉDIO", "YAW MÍNIMO", "graus"],
  ["ESTERÇAMENTO MÁXIMO", "ESTERÇAMENTO MÉDIO", "ESTERÇAMENTO MÍNIMO", "graus"],
  ["LATITUDE", "LONGITUDE", "", ""],
  ["TEMPERATURA MÁXIMA", "TEMPERATURA MÉDIA", "TEMPERATURA MÍNIMA", "°C"],
  ["PRESSAO FREIO MÁXIMA", "PRESSAO FREIO MÉDIA", "PRESSAO FREIO MÍNIMA", "BAR"],
];

List<List<String>> CARD_INFO_INDIVIDUAL = [
  ["ACELERAÇÃO X MÁXIMA", "ACELERAÇÃO X MÉDIA", "ACELERACAO X MÍNIMA", "m/s²"],
  ["ACELERAÇÃO Y MÁXIMA", "ACELERAÇÃO Y MÉDIA", "ACELERACAO Y MÍNIMA", "m/s²"],
  ["ACELERAÇÃO Z MÁXIMA", "ACELERAÇÃO Z MÉDIA", "ACELERACAO Z MÍNIMA", "m/s²"],
  ["ROLL MÁXIMO", "ROLL MÉDIO", "ROLL MÍNIMO", "graus"],
  ["PITCH MÁXIMO", "PITCH MÉDIO", "PITCH MÍNIMO", "graus"],
  ["YAW MÁXIMO", "YAW MÉDIO", "YAW MÍNIMO", "graus"],
  ["VELOCIDADE X MÁXIMA", "VELOCIDADE X MÉDIA", "VELOCIDADE X MÍNIMO", "graus/s"],
  ["VELOCIDADE Y MÁXIMA", "VELOCIDADE Y MÉDIA", "VELOCIDADE Y MÍNIMO", "graus/s"],
  ["VELOCIDADE Z MÁXIMA", "VELOCIDADE Z MÉDIA", "VELOCIDADE Z MÍNIMO", "graus/s"],
];

class Chart extends StatefulWidget {
  const Chart({super.key});

  @override
  State<Chart> createState() => _ChartState();
}

class _ChartState extends State<Chart> {

  bool _shouldDisplayFutureBuilderSingularFile = false;
  bool _shouldDisplayOptions = false;
  double maxValue = 0;
  double avgValue = 0;
  int chartColumnOption = 17;
  Set<String> _chartQualitySelection = {"Performance"};
  Set<String> _chartGroupChoice = {"Individual"};
  double _sliderFilterParam = 1;

  List<bool> isButtonPressedIndividual = [
    false,
    false,
    false,
    false
  ];

  List<bool> isButtonPressedGroup = [
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 15.0),
                child: Image(
                  image: AssetImage('images/lav-logo.png'),
                  height: 150,
                  width: 150,
                ),
              ),
            ],
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _shouldDisplayFutureBuilderSingularFile
                    ? FutureBuilder(
                    future: processCsv(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        if (_chartGroupChoice.contains("Individual")) {
                          return buildChartIndividual(
                              context, snapshot.data!, chartColumnOption, _chartQualitySelection, _sliderFilterParam, _chartGroupChoice);
                        }
                        else {
                          return buildChartGroup(
                              context, snapshot.data!, isButtonPressedIndividual, _chartQualitySelection, _sliderFilterParam, _chartGroupChoice);
                        }
                      } else {
                        return CircularProgressIndicator();
                      }
                    })
                    : const SizedBox(),
                SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MaterialButton(
                        elevation: 20,
                        padding: EdgeInsets.all(17),
                        color: Colors.black54,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(15))),
                        child: Text("Arquivo Único", style: TextStyle(color: Colors.deepOrange)),
                        onPressed: () {
                          setState(() {
                            _shouldDisplayFutureBuilderSingularFile = false;
                            _shouldDisplayOptions = true;
                          });
                        }),
                  ],
                ),
                SizedBox(height: 10,), //_chartGroupChoice
                SizedBox(
                  width: 280,
                  child: SegmentedButton(
                    selectedIcon: Icon(Icons.check, color: Colors.yellow,),
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.black54),
                    ),
                    segments: [
                      ButtonSegment(
                        value: "Performance",
                        label: Text("Performance",  style: TextStyle(color: Colors.deepOrange)),
                      ),
                      ButtonSegment(
                        value: "Qualidade",
                        label: Text("Qualidade",  style: TextStyle(color: Colors.deepOrange)),
                      ),
                    ],
                    selected: _chartQualitySelection,
                    onSelectionChanged: (newSelection) => {
                      setState(() {
                        _chartQualitySelection = newSelection;
                      })
                    },
                  ),
                ),
                SizedBox(height: 10,),
                SizedBox(
                  width: 280,
                  child: SegmentedButton(
                    selectedIcon: Icon(Icons.check, color: Colors.yellow,),
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.black54),
                    ),
                    segments: [
                      ButtonSegment(
                        value: "Individual",
                        label: Text("Individual", style: TextStyle(color: Colors.deepOrange)),
                      ),
                      ButtonSegment(
                        value: "Grupo",
                        label: Text("Grupo", style: TextStyle(color: Colors.deepOrange)),
                      ),
                    ],
                    selected: _chartGroupChoice,
                    onSelectionChanged: (newSelection) => {
                      setState(() {
                        _chartGroupChoice = newSelection;
                      })
                    },
                  ),
                ),
                SizedBox(height: 10,),
                Text("Parâmetros do filtro", style: TextStyle(color: Colors.deepOrange)),
                SizedBox(
                  width: 400,
                  child: Slider(
                    activeColor: Colors.deepOrange,
                    value: _sliderFilterParam,
                    max: 50,
                    min: 1,
                    divisions: 50,
                    label: _sliderFilterParam.round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        _sliderFilterParam = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 10,
          ),
          _shouldDisplayOptions
              ? (_chartGroupChoice.contains("Grupo") ?
          Card(
            elevation: 30,
            color: Colors.black12,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isButtonPressedIndividual = isButtonPressedIndividual
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedIndividual[0] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedIndividual[0] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 285,
                          child: Text("Aceleracao X | Aceleração Y | Aceleração Z", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isButtonPressedIndividual = isButtonPressedIndividual
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedIndividual[1] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedIndividual[1] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 285,
                          child: Text("Roll | Pitch | Yaw", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isButtonPressedIndividual = isButtonPressedIndividual
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedIndividual[2] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedIndividual[2] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 285,
                          child: Text("Velocidade X | Velocidade Y | Velocidade Z", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _shouldDisplayFutureBuilderSingularFile = true;
                      _shouldDisplayOptions = false;
                    }),
                    icon: Icon(Icons.check, color: Colors.deepOrange,),
                  )
                ],
              ),
            ),
          ) :
          Card(
            elevation: 30,
            color: Colors.black12,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 0;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[0] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[0] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Aceleracao X", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 1;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[1] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[1] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Aceleracao Y", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 2;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[2] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[2] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Aceleracao Z", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 7;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[3] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[3] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Roll", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 8;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[4] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[4] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Pitch", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 9;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[5] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[5] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Yaw", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 17;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[6] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[6] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Velocidade", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 16;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[7] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[7] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Latitude/Longitude", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 18;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[8] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[8] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Esterçamento", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 22;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[9] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[9] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Temp. Pastilha", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          chartColumnOption = 23;
                          isButtonPressedGroup = isButtonPressedGroup
                              .map(
                                (e) => false,
                          )
                              .toList();
                          isButtonPressedGroup[10] = true;
                        });
                      },
                      style: ButtonStyle(backgroundColor: isButtonPressedGroup[10] ? WidgetStateProperty.all(Colors.black38) : WidgetStateProperty.all(Colors.grey[900])),
                      child: SizedBox(
                          width: 125,
                          child: Text("Pressão Freio", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
                  SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _shouldDisplayFutureBuilderSingularFile = true;
                      _shouldDisplayOptions = false;
                    }),
                    icon: Icon(Icons.check, color: Colors.deepOrange,),
                  )
                ],
              ),
            ),
          ))
              : SizedBox()
        ],
      ),
    );
  }
}

Future<Object?> getFilePath(bool isMultiple) async {
  final result = await FilePicker.platform.pickFiles(allowMultiple: isMultiple);
  if (result == null) return null;
  if (!isMultiple) {
    return result.files.first.path;
  }
  List<String> listOfPaths = [];
  result.files.forEach((element) => listOfPaths.add(element.path.toString()),);
  return listOfPaths;
}

Future<List<List<dynamic>>> processCsv() async {
  String? path = await getFilePath(false) as String;

  var result = await File(path!).readAsString();
  var csvList = const CsvToListConverter().convert(result, eol: "\n");

  return csvList;
}

Widget buildChartIndividual(
    BuildContext context, List<List<dynamic>> csvData, int value_column, Set<String> chartQuality, double sliderFilterParam, Set<String> chartGroupChoice) {
  List<DataPoints> _dataPoints = [];
  List<DataPointsGPS> _dataPointsGps = [];

  var time_column = COLUMNS.HOUR.index;

  double maxYAxis = csvData[1][value_column].toDouble();
  double minYAxis = csvData[1][value_column].toDouble();

  int csvLength = 0;
  double totalSum = 0;

  List<String> chartInfo = getInfoCard(value_column);

  bool isPerformance = chartQuality.contains("Performance");

  List<DataPoints> _dataPoints2 = [];

  for (var item in csvData.skip(1)) {
    try {
      if (value_column == 16) {
        double long = item[15] as double;
        double lat = item[16] as double;
        _dataPointsGps.add(DataPointsGPS(lat, long));
      }
      if (item[value_column].toDouble() > maxYAxis) {
        maxYAxis = item[value_column].toDouble();
      }
      if (item[value_column].toDouble() < minYAxis) {
        minYAxis = item[value_column].toDouble();
      }
      String rawDateTime = item[time_column].toString();
      int hour = int.parse(rawDateTime.substring(0, 2));
      int minutes = int.parse(rawDateTime.substring(3, 5));
      int seconds = int.parse(rawDateTime.substring(6, 8));
      int miliseconds = int.parse(rawDateTime.substring(9, 11));
      DateTime dateTime = DateTime(0, 0, 0, hour, minutes, seconds, miliseconds);
      _dataPoints.add(DataPoints(dateTime, item[value_column]));
      totalSum += item[value_column].toDouble();
      csvLength += 1;
      if (value_column == 17) {
        _dataPoints2.add(DataPoints(dateTime, item[21])); // Add vel. hall
      }
    } catch (e) {
      print("DEU ERRO: ${e}");
    }
  }
  ;

  double avgValue = totalSum / csvLength;

  List<DataPoints> _dataPointsFiltered = [];
  List<DataPoints> _dataPointsFiltered2 = [];
  double maxYAxis2 = 0.0;
  double minYAxis2 = 0.0;
  double avgValue2 = 0.0;
  if (value_column != 16) {
    var ret = getFilteredValues(sliderFilterParam.round(), _dataPoints, chartGroupChoice);
    _dataPointsFiltered = ret[0] as List<DataPoints>;
    maxYAxis = ret[1] as double;
    minYAxis = ret[2] as double;
    avgValue = ret[3] as double;

    if (value_column == 17) {
      var ret = getFilteredValues(sliderFilterParam.round(), _dataPoints2, chartGroupChoice);
      _dataPointsFiltered2 = ret[0] as List<DataPoints>;
      maxYAxis2 = ret[1] as double;
      minYAxis2 = ret[2] as double;
      avgValue2 = ret[3] as double;
    }

  }

  return Column(
    children: [
      value_column == 16
          ? SizedBox()
          : (value_column != 17 ? Padding(
        padding: const EdgeInsets.only(left: 40.0),
        child: Card(
          elevation: 20,
          color: Colors.orange[500],
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Column(
              children: [
                Column(
                  children: [
                    Text(chartInfo[0]),
                    Text(
                        "${maxYAxis.toStringAsFixed(2)} ${chartInfo[3]}"),
                  ],
                ),
                SizedBox(
                  height: 15,
                ),
                Column(
                  children: [
                    Text(chartInfo[1]),
                    Text("${avgValue.toStringAsFixed(2)} ${chartInfo[3]}")
                  ],
                ),
                SizedBox(
                  height: 15,
                ),
                Column(
                  children: [
                    Text(chartInfo[2]),
                    Text("${minYAxis.toStringAsFixed(2)} ${chartInfo[3]}")
                  ],
                ),
              ],
            ),
          ),
        ),
      ) : Padding(
        padding: const EdgeInsets.only(left: 40.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 20,
              color: Colors.orange[500],
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Column(
                      children: [
                        Text(chartInfo[0]),
                        Text(
                            "${maxYAxis.toStringAsFixed(2)} ${chartInfo[3]}"),
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Column(
                      children: [
                        Text(chartInfo[1]),
                        Text("${avgValue.toStringAsFixed(2)} ${chartInfo[3]}")
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Column(
                      children: [
                        Text(chartInfo[2]),
                        Text("${minYAxis.toStringAsFixed(2)} ${chartInfo[3]}")
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 20,
              color: Colors.blue[500],
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Column(
                      children: [
                        Text("VELOCIDADE HALL MAXIMA"),
                        Text(
                            "${maxYAxis2.toStringAsFixed(2)} km/h"),
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Column(
                      children: [
                        Text("VELOCIDADE HALL MEDIA"),
                        Text("${avgValue2.toStringAsFixed(2)} km/h")
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Column(
                      children: [
                        Text("VELOCIDADE HALL MINIMA"),
                        Text("${minYAxis2.toStringAsFixed(2)} km/h")
                      ],
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      )
      ),
      SfCartesianChart(
        title: ChartTitle(
          text: value_column == 16
              ? "Longitude x Latitude"
              : "${chartInfo[0].split(" ")[0].toLowerCase()} em função do tempo",
          textStyle: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        enableAxisAnimation: true,
        tooltipBehavior: TooltipBehavior(
          color: Colors.deepOrange,
          enable: true,
          borderColor: Colors.deepOrange,
          borderWidth: 2,
          builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
            String velGps = "${csvData[pointIndex][17].toString()}";
            String velHall = "${csvData[pointIndex][21].toString()}";
            String tempTermopar = "${csvData[pointIndex][22].toString()}";
            String brakeVal = "${csvData[pointIndex][23].toStringAsFixed(2)}";
            return Container(
                child: Text(
                    'Velocidade GPS: $velGps km/h\nVelocidade Hall: $velHall km/h\nPressão Freio: $brakeVal bar\nTemperatura Pastilha: $tempTermopar °C',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                )
            );
          }
        ),
        zoomPanBehavior: ZoomPanBehavior(
          enablePanning: true,
          enableMouseWheelZooming: true,
          enablePinching: true,
        ),
        primaryXAxis: value_column != 16
            ? (isPerformance ? DateTimeAxis(
          labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500),
          title: AxisTitle(text: "Horário", textStyle: TextStyle(color: Colors.white)),
        ) : DateTimeCategoryAxis(
          labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500),
          title: AxisTitle(text: "Horário", textStyle: TextStyle(color: Colors.white)),
        ))
            : NumericAxis(
          labelStyle: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500),
          title: AxisTitle(text: "Latitude", textStyle: TextStyle(color: Colors.white)),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          title: AxisTitle(
              text:
              "${chartInfo[0].split(" ")[0].toLowerCase()} [${chartInfo[3]}]", textStyle: TextStyle(color: Colors.white)),
          minimum: value_column != 16 ? (minYAxis - 1) : null,
          maximum: value_column != 16 ? (maxYAxis + 1) : null,
        ),
        series: value_column != 16
            ? (value_column != 17 ? <FastLineSeries<DataPoints, DateTime>>[
          // Initialize line series with data points
          FastLineSeries<DataPoints, DateTime>(
            color: Colors.orange[500],
            dataSource: _dataPointsFiltered,
            xValueMapper: (DataPoints value, _) => value.x,
            yValueMapper: (DataPoints value, _) => value.y,
          ),
        ] : <FastLineSeries<DataPoints, DateTime>>[
          // Initialize line series with data points
          FastLineSeries<DataPoints, DateTime>(
            color: Colors.orange[500],
            dataSource: _dataPointsFiltered,
            xValueMapper: (DataPoints value, _) => value.x,
            yValueMapper: (DataPoints value, _) => value.y,
          ),
          FastLineSeries<DataPoints, DateTime>(
            color: Colors.blue[500],
            dataSource: _dataPointsFiltered2,
            xValueMapper: (DataPoints value, _) => value.x,
            yValueMapper: (DataPoints value, _) => value.y,
          ),
        ])
            : <ChartSeries<DataPointsGPS, double>>[
          // Initialize line series with data points
          LineSeries<DataPointsGPS, double>(
            color: Colors.orange[500],
            dataSource: _dataPointsGps,
            xValueMapper: (DataPointsGPS value, _) => value.x,
            yValueMapper: (DataPointsGPS value, _) => value.y,
          ),
        ].cast<CartesianSeries>(),
      ),
    ],
  );
}

Widget buildChartGroup(
    BuildContext context, List<List<dynamic>> csvData, List<bool> pressedButtonOption, Set<String> chartQuality, double sliderFilterParam, Set<String> chartGroupChoice) {
  List<DataPoints> _dataPoints1 = [];
  List<DataPoints> _dataPoints2 = [];
  List<DataPoints> _dataPoints3 = [];

  List<DataPoints> _dataPointsFiltered1 = [];
  List<DataPoints> _dataPointsFiltered2 = [];
  List<DataPoints> _dataPointsFiltered3 = [];

  var time_column = COLUMNS.HOUR.index;

  List<int> values_column = [0, 0, 0];
  if (pressedButtonOption[0] == true) {
    values_column = [0, 1, 2];
  }
  else if (pressedButtonOption[1] == true) {
    values_column = [7, 8, 9];
  }
  else if (pressedButtonOption[2] == true) {
    values_column = [4, 5, 6];
  }
  else if (pressedButtonOption[3] == true) {
    values_column = [22, 23, 24];
  }


  List<String> chartInfo1 = getInfoCard(values_column[0]);
  List<String> chartInfo2 = getInfoCard(values_column[1]);
  List<String> chartInfo3 = getInfoCard(values_column[2]);

  bool isPerformance = chartQuality.contains("Performance");

  for (var item in csvData.skip(1)) {
    try {
      String rawDateTime = item[time_column].toString();
      int hour = int.parse(rawDateTime.substring(0, 2));
      int minutes = int.parse(rawDateTime.substring(3, 5));
      int seconds = int.parse(rawDateTime.substring(6, 8));
      int miliseconds = int.parse(rawDateTime.substring(9, 11));
      DateTime dateTime = DateTime(0, 0, 0, hour, minutes, seconds, miliseconds);
      _dataPoints1.add(DataPoints(dateTime, item[values_column[0]]));
      _dataPoints2.add(DataPoints(dateTime, item[values_column[1]]));
      _dataPoints3.add(DataPoints(dateTime, item[values_column[2]]));
    } catch (e) {
      print("DEU ERRO: ${e}");
    }
  }
  ;


  var ret = getFilteredValues(sliderFilterParam.round(), [_dataPoints1, _dataPoints2, _dataPoints3], chartGroupChoice);
  _dataPointsFiltered1 = ret[0] as List<DataPoints>;
  _dataPointsFiltered2 = ret[1] as List<DataPoints>;
  _dataPointsFiltered3 = ret[2] as List<DataPoints>;
  double maxY1Axis = ret[3] as double;
  double minY1Axis = ret[4] as double;
  double avgValue1 = ret[5] as double;
  double maxY2Axis = ret[6] as double;
  double minY2Axis = ret[7] as double;
  double avgValue2 = ret[8] as double;
  double maxY3Axis = ret[9] as double;
  double minY3Axis = ret[10] as double;
  double avgValue3 = ret[11] as double;


  double maxY = [maxY1Axis, maxY2Axis, maxY3Axis].reduce(max);
  double minY = [minY1Axis, minY2Axis, minY3Axis].reduce(min);

  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 40.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Card(
              elevation: 20,
              color: Colors.yellow[500],
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Column(
                      children: [
                        Text(chartInfo1[0]),
                        Text(
                            "${maxY1Axis.toStringAsFixed(2)} ${chartInfo1[3]}"),
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Column(
                      children: [
                        Text(chartInfo1[1]),
                        Text("${avgValue1.toStringAsFixed(2)} ${chartInfo1[3]}")
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Column(
                      children: [
                        Text(chartInfo1[2]),
                        Text("${minY1Axis.toStringAsFixed(2)} ${chartInfo1[3]}")
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 20,
              color: Colors.greenAccent,
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Column(
                      children: [
                        Text(chartInfo2[0]),
                        Text(
                            "${maxY2Axis.toStringAsFixed(2)} ${chartInfo2[3]}"),
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Column(
                      children: [
                        Text(chartInfo2[1]),
                        Text("${avgValue2.toStringAsFixed(2)} ${chartInfo2[3]}")
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Column(
                      children: [
                        Text(chartInfo2[2]),
                        Text("${minY2Axis.toStringAsFixed(2)} ${chartInfo2[3]}")
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 20,
              color: Colors.blue[500],
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Column(
                      children: [
                        Text(chartInfo3[0]),
                        Text(
                            "${maxY3Axis.toStringAsFixed(2)} ${chartInfo3[3]}"),
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Column(
                      children: [
                        Text(chartInfo3[1]),
                        Text("${avgValue3.toStringAsFixed(2)} ${chartInfo3[3]}")
                      ],
                    ),
                    SizedBox(
                      height: 15,
                    ),
                    Column(
                      children: [
                        Text(chartInfo3[2]),
                        Text("${minY3Axis.toStringAsFixed(2)} ${chartInfo3[3]}")
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      SfCartesianChart(
          title: ChartTitle(
            text: "${chartInfo1[0].split(" ")[0].toLowerCase()} em função do tempo",
            textStyle: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          enableAxisAnimation: true,
          tooltipBehavior: TooltipBehavior(
            color: Colors.deepOrange,
            enable: true,
            borderColor: Colors.deepOrange,
            borderWidth: 2,
            header: "",
          ),
          zoomPanBehavior: ZoomPanBehavior(
            enablePanning: true,
            enableMouseWheelZooming: true,
            enablePinching: true,
          ),
          primaryXAxis: isPerformance ? DateTimeAxis(
            labelStyle: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            title: AxisTitle(text: "Horário", textStyle: TextStyle(color: Colors.white)),
          ) : DateTimeCategoryAxis(
            labelStyle: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            title: AxisTitle(text: "Horário", textStyle: TextStyle(color: Colors.white)),
          ),
          primaryYAxis: NumericAxis(
            labelStyle: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            title: AxisTitle(
                text: "${chartInfo1[0].split(" ")[0].toLowerCase()} [${chartInfo1[3]}]", textStyle: TextStyle(color: Colors.white)),
            minimum: minY - 1,
            maximum: maxY + 1,
          ),
          series: <FastLineSeries<DataPoints, DateTime>>[
            // Initialize line series with data points
            FastLineSeries<DataPoints, DateTime>(
              color: Colors.yellow[500],
              dataSource: _dataPointsFiltered1,
              xValueMapper: (DataPoints value, _) => value.x,
              yValueMapper: (DataPoints value, _) => value.y,
            ),
            FastLineSeries<DataPoints, DateTime>(
              color: Colors.greenAccent,
              dataSource: _dataPointsFiltered2,
              xValueMapper: (DataPoints value, _) => value.x,
              yValueMapper: (DataPoints value, _) => value.y,
            ),
            FastLineSeries<DataPoints, DateTime>(
              color: Colors.blue[500],
              dataSource: _dataPointsFiltered3,
              xValueMapper: (DataPoints value, _) => value.x,
              yValueMapper: (DataPoints value, _) => value.y,
            ),
          ]
      ),
    ],
  );
}

List<String> getInfoCard(int value_column) {
  switch (value_column) {
    case 0:
      return CARD_INFO_INDIVIDUAL[0];
    case 1:
      return CARD_INFO_INDIVIDUAL[1];
    case 2:
      return CARD_INFO_INDIVIDUAL[2];
    case 4:
      return CARD_INFO_INDIVIDUAL[6];
    case 5:
      return CARD_INFO_INDIVIDUAL[7];
    case 6:
      return CARD_INFO_INDIVIDUAL[8];
    case 7:
      return CARD_INFO_GROUP[2];
    case 8:
      return CARD_INFO_GROUP[3];
    case 9:
      return CARD_INFO_GROUP[4];
    case 17:
      return CARD_INFO_GROUP[1];
    case 18:
      return CARD_INFO_GROUP[5];
    case 16:
      return CARD_INFO_GROUP[6];
    case 22:
      return CARD_INFO_GROUP[7];
    case 23:
      return CARD_INFO_GROUP[8];
    case 24:
      return CARD_INFO_GROUP[9];
  }

  return [""];
}

// Try to optimize this.
List<Object> getFilteredValues<T>(int filterParam, T originalList, Set<String> chartGroupChoice) {
  final simpleMovingAverage = MovingAverage<num>(
    averageType: AverageType.simple,
    windowSize: filterParam,
    partialStart: true,
    getValue: (num n) => n,
    add: (List<num> data, num value) => value,
  );

  if (chartGroupChoice.contains("Individual")) {
    List<DataPoints> filteredList = [];
    List<num> filteredValues = [];
    for (var element in originalList as List<DataPoints>) {
      filteredValues.add(element.y!);
    }
    filteredValues = simpleMovingAverage(filteredValues);
    for (int i = 0 ; i < originalList.length; i++) {
      num valueFiltered = filteredValues[i];
      DateTime? dateTime = originalList[i].x;
      filteredList.add(DataPoints(dateTime, valueFiltered));
    }

    double maxValue = filteredValues.reduce(max) as double;
    double minValue = filteredValues.reduce(min) as double;
    double avgValue = (filteredValues.sum) / filteredValues.length;

    return [filteredList, maxValue, minValue, avgValue];
  }

  List<List<DataPoints>> originalListCasted = originalList as List<List<DataPoints>>;
  int loopSize = originalListCasted[0].length;

  List<DataPoints> filteredList1 = [];
  List<DataPoints> filteredList2 = [];
  List<DataPoints> filteredList3 = [];
  List<num> filteredValues1 = [];
  List<num> filteredValues2 = [];
  List<num> filteredValues3 = [];
  for (int i = 0 ; i < loopSize; i++) {
    filteredValues1.add(originalListCasted[0][i].y!);
    filteredValues2.add(originalListCasted[1][i].y!);
    filteredValues3.add(originalListCasted[2][i].y!);
  }
  filteredValues1 = simpleMovingAverage(filteredValues1);
  filteredValues2 = simpleMovingAverage(filteredValues2);
  filteredValues3 = simpleMovingAverage(filteredValues3);
  for (int i = 0 ; i < loopSize; i++) {
    num valueFiltered1 = filteredValues1[i];
    num valueFiltered2 = filteredValues2[i];
    num valueFiltered3 = filteredValues3[i];
    DateTime? dateTime = originalList[0][i].x;
    filteredList1.add(DataPoints(dateTime, valueFiltered1));
    filteredList2.add(DataPoints(dateTime, valueFiltered2));
    filteredList3.add(DataPoints(dateTime, valueFiltered3));
  }

  double maxValue1 = filteredValues1.reduce(max) as double;
  double minValue1 = filteredValues1.reduce(min) as double;
  double avgValue1 = (filteredValues1.sum) / filteredValues1.length;
  double maxValue2 = filteredValues2.reduce(max) as double;
  double minValue2 = filteredValues2.reduce(min) as double;
  double avgValue2 = (filteredValues2.sum) / filteredValues2.length;
  double maxValue3 = filteredValues3.reduce(max) as double;
  double minValue3 = filteredValues3.reduce(min) as double;
  double avgValue3 = (filteredValues3.sum) / filteredValues3.length;

  return [filteredList1, filteredList2, filteredList3, maxValue1, minValue1, avgValue1, maxValue2, minValue2, avgValue2, maxValue3, minValue3, avgValue3];

}

class DataPoints {
  DataPoints(this.x, this.y);

  final DateTime? x;
  late final num? y;
}

class DataPointsGPS {
  DataPointsGPS(this.x, this.y);

  final double? x;
  final double? y;
}

class DataPointsCompare {
  DataPointsCompare(this.x, this.y);

  final double? x;
  final double? y;
}