import 'package:flutter/material.dart';

class PolicyCoveragesSection extends StatelessWidget {
  final List<String> allCoverages;
  final List<String> selectedCoverages;
  final void Function(String coverage, bool isSelected) onCoverageToggled;

  const PolicyCoveragesSection({
    super.key,
    required this.allCoverages,
    required this.selectedCoverages,
    required this.onCoverageToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Coberturas Contratadas:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        ...allCoverages.map(
          (cov) => CheckboxListTile(
            dense: true,
            title: Text(cov, style: const TextStyle(fontSize: 13)),
            value: selectedCoverages.contains(cov),
            onChanged: (on) => onCoverageToggled(cov, on == true),
          ),
        ),
      ],
    );
  }
}
