import 'package:biosensesignal_flutter_sdk/vital_signs/vital_sign_types.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/diabetes_risk.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign.dart';

class VitalSignDiabetesRisk extends VitalSign<DiabetesRisk> {
  VitalSignDiabetesRisk(DiabetesRisk value) : super(VitalSignTypes.diabetesRisk, value);

  @override
  String toString() {
    return value.toString();
  }
}
