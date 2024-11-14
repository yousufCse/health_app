import 'package:biosensesignal_flutter_sdk/vital_signs/vital_sign_types.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/hypertension_risk.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign.dart';

class VitalSignHypertensionRisk extends VitalSign<HypertensionRisk> {
  VitalSignHypertensionRisk(HypertensionRisk value) : super(VitalSignTypes.hypertensionRisk, value);

  @override
  String toString() {
    return value.toString();
  }
}
