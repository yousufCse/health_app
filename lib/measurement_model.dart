import 'dart:async';
import 'dart:developer';

import 'package:biosensesignal_flutter_sdk/alerts/alert_codes.dart';
import 'package:biosensesignal_flutter_sdk/alerts/error_data.dart';
import 'package:biosensesignal_flutter_sdk/alerts/warning_data.dart';
import 'package:biosensesignal_flutter_sdk/health_monitor_exception.dart';
import 'package:biosensesignal_flutter_sdk/images/image_data.dart'
    as sdk_image_data;
import 'package:biosensesignal_flutter_sdk/images/image_data_listener.dart';
import 'package:biosensesignal_flutter_sdk/images/image_validity.dart';
import 'package:biosensesignal_flutter_sdk/license/license_details.dart';
import 'package:biosensesignal_flutter_sdk/license/license_info.dart';
import 'package:biosensesignal_flutter_sdk/session/session.dart';
import 'package:biosensesignal_flutter_sdk/session/session_builder/face_session_builder.dart';
import 'package:biosensesignal_flutter_sdk/session/session_enabled_vital_signs.dart';
import 'package:biosensesignal_flutter_sdk/session/session_info_listener.dart';
import 'package:biosensesignal_flutter_sdk/session/session_state.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vital_sign_types.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vital_signs_listener.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vital_signs_results.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign_blood_pressure.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign_diabetes_risk.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign_hemoglobin.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign_hypertension_risk.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign_oxygen_saturation.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign_pulse_rate.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign_respiration_rate.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign_stress_level.dart';
import 'package:biosensesignal_flutter_sdk/vital_signs/vitals/vital_sign_wellness_level.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MeasurementModel extends ChangeNotifier
    implements SessionInfoListener, VitalSignsListener, ImageDataListener {
  final licenseKey = "Place Your Lisence Key";
  final measurementDuration = 60;
  Session? _session;
  sdk_image_data.ImageData? imageData;

  String? error;
  String? warning;
  SessionState? sessionState;
  String? pulseRate;
  String? finalResultsString;
  String imageValidityString = "";
  bool showImageValidity = false;

  Map<String, dynamic> vitalSignData = {};
  Map<String, dynamic>? finalResultData;

  screenInFocus(bool focus) async {
    if (focus) {
      if (!await _requestCameraPermission()) {
        return;
      }

      _createSession();
    } else {
      _terminateSession();
    }
  }

  void startStopButtonClicked() {
    showImageValidity = false;
    switch (sessionState) {
      case SessionState.ready:
        _startMeasuring();
        break;
      case SessionState.processing:
        _stopMeasuring();
        break;
      default:
        break;
    }
  }

  @override
  void onImageData(sdk_image_data.ImageData imageData) {
    this.imageData = imageData;
    if (imageData.imageValidity != ImageValidity.valid) {
      showImageValidity = true;
      switch (imageData.imageValidity) {
        case ImageValidity.invalidDeviceOrientation:
          imageValidityString = "Invalid Orientation";
          break;
        case ImageValidity.invalidRoi:
          imageValidityString = "Face Not Detected";
          break;
        case ImageValidity.tiltedHead:
          imageValidityString = "Titled Head";
          break;
        case ImageValidity.faceTooFar:
          imageValidityString = "You are Too Far";
          break;
        case ImageValidity.unevenLight:
          imageValidityString = "Uneven Lighting";
          break;
      }
    } else {
      showImageValidity = false;
    }
    notifyListeners();
  }

  @override
  void onVitalSign(VitalSign vitalSign) {
    final currentData = switch (vitalSign.type) {
      VitalSignTypes.pulseRate => {'pulseRate': '${vitalSign.value}'},
      VitalSignTypes.bloodPressure => {'bloodPressure': '${vitalSign.value}'},
      VitalSignTypes.diabetesRisk => {'diabetesRisk': '${vitalSign.value}'},
      VitalSignTypes.hemoglobin => {'hemoglobin': '${vitalSign.value}'},
      VitalSignTypes.oxygenSaturation => {
          'oxygenSaturation': '${vitalSign.value}'
        },
      VitalSignTypes.respirationRate => {
          'respirationRate': '${vitalSign.value}'
        },
      VitalSignTypes.hypertensionRisk => {
          'hypertensionRisk': '${vitalSign.value}'
        },
      VitalSignTypes.stressLevel => {'stressLevel': '${vitalSign.value}'},
      _ => {'noSign': 'No Vital Signs'}
    };

    final key = currentData.keys.first;

    vitalSignData.update(
      key,
      (value) => currentData.values.first,
      ifAbsent: () => currentData.values.first,
    );

    vitalSignData = {...vitalSignData};

    notifyListeners();

    log('Current >>> vitalSignData: $vitalSignData');

    // if (vitalSign.type == VitalSignTypes.pulseRate) {
    //   pulseRate = "PR: ${(vitalSign as VitalSignPulseRate).value}";

    //   notifyListeners();
    // } else if (vitalSign.type == VitalSignTypes.bloodPressure) {
    //   log("umr === blood pressure: ${(vitalSign as VitalSignBloodPressure).value}");
    // } else if (vitalSign.type == VitalSignTypes.hemoglobin) {
    //   log("umr === hemoglobini : ${(vitalSign as VitalSignHemoglobin).value}");
    // }
  }

  @override
  void onFinalResults(VitalSignsResults finalResults) async {
    VitalSignPulseRate? vitalSignPulseRate = (finalResults
        .getResult(VitalSignTypes.pulseRate) as VitalSignPulseRate?);

    VitalSignBloodPressure? vitalSignBloodPressure = (finalResults
        .getResult(VitalSignTypes.bloodPressure) as VitalSignBloodPressure?);

    VitalSignHemoglobin? vitalSignHemoglobin = (finalResults
        .getResult(VitalSignTypes.hemoglobin) as VitalSignHemoglobin?);

    VitalSignOxygenSaturation? vitalSignOxygenSaturation =
        (finalResults.getResult(VitalSignTypes.oxygenSaturation)
            as VitalSignOxygenSaturation?);

    VitalSignRespirationRate? vitalSignRespirationRate =
        (finalResults.getResult(VitalSignTypes.respirationRate)
            as VitalSignRespirationRate?);

    VitalSignDiabetesRisk? vitalSignDiabetesRisk = (finalResults
        .getResult(VitalSignTypes.diabetesRisk) as VitalSignDiabetesRisk?);

    VitalSignHypertensionRisk? vitalSignHypertensionRisk =
        (finalResults.getResult(VitalSignTypes.hypertensionRisk)
            as VitalSignHypertensionRisk?);

    VitalSignWellnessLevel? vitalSignWellnessLevel = (finalResults
        .getResult(VitalSignTypes.wellnessLevel) as VitalSignWellnessLevel?);

    VitalSignStressLevel? vitalSignStressLevel = (finalResults
        .getResult(VitalSignTypes.stressLevel) as VitalSignStressLevel?);

    finalResultData = {
      'pulseRate': {
        'value': vitalSignPulseRate?.value,
        'confidenceLevel': vitalSignPulseRate?.confidence?.level.name
      },
      'bloodPressure': {
        'systolic': vitalSignBloodPressure?.value.systolic,
        'diastolic': vitalSignBloodPressure?.value.diastolic,
      },
      'hemoglobin': {
        'value': vitalSignHemoglobin?.value,
      },
      'oxygenSaturation': {
        'value': vitalSignOxygenSaturation?.value,
      },
      'respirationRate': {
        'value': vitalSignRespirationRate?.value,
        'confidenceLevel': vitalSignRespirationRate?.confidence?.level.name,
      },
      'diabetesRisk': {
        'value': vitalSignDiabetesRisk?.value.name,
      },
      'hypertensionRisk': {
        'value': vitalSignHypertensionRisk?.value.name,
      },
      'wellnessLevel': {
        'value': vitalSignWellnessLevel?.value.name,
      },
      'stressLevel': {
        'value': vitalSignStressLevel?.value.name,
      },
    };

    // final pulseRate = {'pulseRate': pulseRateValue};

    // var meanRriValue =
    //     (finalResults.getResult(VitalSignTypes.bloodPressure) as BloodPressure?)
    //             ?.systolic ??
    //         "N/A";
    // final pulseRate = {'pulseRate': pulseRateValue};

    notifyListeners();
  }

  @override
  void onWarning(WarningData warningData) {
    if (warning != null) {
      return;
    }

    if (warningData.code ==
        AlertCodes.measurementCodeMisdetectionDurationExceedsLimitWarning) {
      pulseRate = "";
    }

    warning = "Warning: ${warningData.code}";
    notifyListeners();
    Future.delayed(const Duration(seconds: 1), () {
      warning = null;
    });
  }

  @override
  void onError(ErrorData errorData) {
    error = "Error: ${errorData.code}";
    notifyListeners();
  }

  @override
  void onSessionStateChange(SessionState sessionState) async {
    this.sessionState = sessionState;
    switch (sessionState) {
      case SessionState.ready:
        // WakelockPlus.enable();
        await WakelockPlus.enable();
        break;
      case SessionState.terminating:
        // Wakelock.disable();
        WakelockPlus.disable();
        break;
      default:
        break;
    }

    notifyListeners();
  }

  @override
  void onEnabledVitalSigns(SessionEnabledVitalSigns enabledVitalSigns) {}

  @override
  void onLicenseInfo(LicenseInfo licenseInfo) {}

  Future<void> _createSession() async {
    if (_session != null) {
      await _terminateSession();
    }

    _reset();
    try {
      _session = await FaceSessionBuilder()
          .withImageDataListener(this)
          .withVitalSignsListener(this)
          .withSessionInfoListener(this)
          //.withAnalytics()
          .build(LicenseDetails(licenseKey));
    } on HealthMonitorException catch (e) {
      error = "Error: ${e.code}";
      notifyListeners();
    }
  }

  Future<void> _startMeasuring() async {
    try {
      _reset();
      await _session?.start(measurementDuration);
      notifyListeners();
    } on HealthMonitorException catch (e) {
      error = "Error: ${e.code}";
    }
  }

  Future<void> _stopMeasuring() async {
    try {
      await _session?.stop();
    } on HealthMonitorException catch (e) {
      error = "Error: ${e.code}";
    }
  }

  Future<void> _terminateSession() async {
    await _session?.terminate();
    _session = null;
  }

  void _reset() {
    error = null;
    warning = null;
    pulseRate = null;
    finalResultsString = null;
    finalResultData = null;
    vitalSignData = {};
    notifyListeners();
  }

  Future<bool> _requestCameraPermission() async {
    PermissionStatus result;
    result = await Permission.camera.request();
    return result.isGranted;
  }
}
