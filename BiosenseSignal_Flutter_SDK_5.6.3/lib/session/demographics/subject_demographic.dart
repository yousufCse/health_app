import 'package:biosensesignal_flutter_sdk/session/demographics/sex.dart';

class SubjectDemographic {
  final Sex? sex;
  final double? age;
  final double? weight;
  final double? height;

  SubjectDemographic({this.sex, this.age, this.weight, this.height});
}
