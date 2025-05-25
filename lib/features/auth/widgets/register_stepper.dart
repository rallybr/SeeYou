import 'package:flutter/material.dart';

class RegisterStepper extends StatelessWidget {
  final int currentStep;
  final List<Widget> steps;
  const RegisterStepper({Key? key, required this.currentStep, required this.steps}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stepper(
      currentStep: currentStep,
      steps: [
        Step(title: const Text('Conta'), content: steps[0]),
        Step(title: const Text('Perfil'), content: steps[1]),
        Step(title: const Text('Confirmação'), content: steps[2]),
      ],
      onStepContinue: () {},
      onStepCancel: () {},
    );
  }
} 