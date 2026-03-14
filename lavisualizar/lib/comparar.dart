import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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

class Comparison extends StatefulWidget {
  const Comparison({super.key});

  @override
  State<Comparison> createState() => _ComparisonState();
}

class _ComparisonState extends State<Comparison> {

  bool _shouldDisplayFutureBuilderMultipleFiles = false;
  int chartColumnOption = 17;
  bool _shouldDisplayOptions = false;


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
      body: ListView(
        shrinkWrap: true,
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
                _shouldDisplayFutureBuilderMultipleFiles
                    ? FutureBuilder(
                    future: processCsvMultiple(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        // snapshot.data!.$1 eh o csvData e snapshot.data!.$2 sao os nomes dos arquivos
                        return buildChartComparasion(context, snapshot.data!.$1, chartColumnOption, snapshot.data!.$2);
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
                        child: Text("Selecionar Múltiplos Arquivos", style: TextStyle(color: Colors.deepOrange)),
                        onPressed: () {
                          setState(() {
                            _shouldDisplayFutureBuilderMultipleFiles = true;
                            _shouldDisplayOptions = true;
                          });
                        }),
                  ],
                ),
                SizedBox(height: 10,),
              ],
            ),
          ),
          SizedBox(
            height: 10,
          ),
          _shouldDisplayOptions ? Center(
            child: Card(
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
                            child: Text("Velocidade Linear", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,))),
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
                    IconButton(
                      onPressed: () => setState(() {
                        _shouldDisplayOptions = false;
                      }),
                      icon: Icon(Icons.check, color: Colors.deepOrange,),
                    )
                  ],
                ),
              ),
            ),
          ) : SizedBox()
        ],
      ),
    );
  }
}

Widget buildChartComparasion(BuildContext context, List<List<List<dynamic>>> csvData, int value_column, List<String> fileNames) {

  int numberOfFiles = csvData.length;

  List<FastLineSeries<DataPointsCompare, double>> series = [];
  List<Widget> cardsInfo = [];
  List<Color> possibleColors = [Colors.yellow, Colors.greenAccent, Colors.blue, Colors.red, Colors.purple, Colors.brown, Colors.white, Colors.black];
  List<String> chartColumnInfo = getInfoCard(value_column);

  for (int i = 0; i < numberOfFiles; i++) {
    double count = 0;
    double maxYAxis = csvData[i][value_column+1][0] as double;
    double minYAxis = csvData[i][value_column+1][0] as double;
    double totalSum = 0;
    List<DataPointsCompare> dummy = [];

    for (var item in csvData[i].skip(1)) {
      try {
        if (item[value_column] as double > maxYAxis) {
          maxYAxis = item[value_column] as double;
        }
        if (item[value_column] as double < minYAxis) {
          minYAxis = item[value_column] as double;
        }
        dummy.add(DataPointsCompare(count, item[value_column]));
        count++;
        totalSum += item[value_column];
      } catch (e) {
        print("DEU ERRO: ${e}");
      }
    }

    double avg = totalSum / count;

    series.add(
        FastLineSeries<DataPointsCompare, double>(
          color: possibleColors[i],
          dataSource: dummy,
          xValueMapper: (DataPointsCompare value, _) => value.x,
          yValueMapper: (DataPointsCompare value, _) => value.y,
        )
    );
    var formatedString = fileNames[i].split(r"\").last;
    cardsInfo.add(
      Card(
        elevation: 20,
        color: possibleColors[i],
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text("${formatedString}"),
              SizedBox(
                height: 15,
              ),
              Column(
                children: [
                  Text(chartColumnInfo[0]),
                  Text(
                      "${maxYAxis.toStringAsFixed(2)} ${chartColumnInfo[3]}"),
                ],
              ),
              SizedBox(
                height: 15,
              ),
              Column(
                children: [
                  Text(chartColumnInfo[1]),
                  Text("${avg.toStringAsFixed(2)} ${chartColumnInfo[3]}")
                ],
              ),
              SizedBox(
                height: 15,
              ),
              Column(
                children: [
                  Text(chartColumnInfo[2]),
                  Text("${minYAxis.toStringAsFixed(2)} ${chartColumnInfo[3]}")
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 40.0),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ...cardsInfo.map((card) {
                return card;
              },),]
        ),
      ),
      SfCartesianChart(
          title: ChartTitle(
            text: "${chartColumnInfo[0].split(" ")[0].toLowerCase()} em função do tempo",
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
          primaryXAxis: NumericAxis(
              labelStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
              title: AxisTitle(text: "Pontos")
          ),
          primaryYAxis: NumericAxis(
            labelStyle: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            title: AxisTitle(
                text: "${chartColumnInfo[0].split(" ")[0].toLowerCase()} [${chartColumnInfo[3]}]"),
          ),
          series: series
      ),
    ],
  );
}

Future<Object?> getFilePath(bool isMultiple) async {
  print("Chamando com: ${isMultiple}");
  final result = await FilePicker.platform.pickFiles(allowMultiple: isMultiple);
  if (result == null) return null;
  if (!isMultiple) {
    return result.files.first.path;
  }
  List<String> listOfPaths = [];
  result.files.forEach((element) => listOfPaths.add(element.path.toString()),);
  return listOfPaths;
}

Future<(List<List<List>>, List<String>)> processCsvMultiple() async {
  List<String> paths = await getFilePath(true) as List<String>;

  List<List<List<dynamic>>> csvList = [];

  for (var file in paths) {
    var result = await File(file!).readAsString();
    var csvData = const CsvToListConverter().convert(result, eol: "\n");
    csvList.add(csvData);
  }

  return (csvList, paths);
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


class DataPoints {
  DataPoints(this.x, this.y);

  final DateTime? x;
  final num? y;
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