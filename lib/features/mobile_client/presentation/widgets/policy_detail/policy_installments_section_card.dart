import 'package:flutter/material.dart';
import 'package:sigad/core/models/payment_model.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/date_formatter.dart';

class PolicyInstallmentsSectionCard extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<PaymentModel> payments;
  final VoidCallback onRetry;

  const PolicyInstallmentsSectionCard({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.payments,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Cronograma de Pagos y Cuotas',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
            ],
          ),
        ),
        if (isLoading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          )
        else if (errorMessage != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(fontSize: 13, color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (payments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  'No hay cuotas registradas para esta póliza.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ),
            ),
          )
        else
          ...payments.map((p) => PolicyInstallmentItemCard(payment: p)),
      ],
    );
  }
}

class PolicyInstallmentItemCard extends StatelessWidget {
  final PaymentModel payment;

  const PolicyInstallmentItemCard({
    super.key,
    required this.payment,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeBg;
    final Color badgeColor;
    final String badgeText = payment.status.toUpperCase();

    if (payment.isPaid) {
      badgeBg = AppTheme.successColor.withValues(alpha: 0.12);
      badgeColor = AppTheme.successColor;
    } else if (payment.isOverdue) {
      badgeBg = AppTheme.errorColor.withValues(alpha: 0.12);
      badgeColor = AppTheme.errorColor;
    } else {
      badgeBg = AppTheme.warningColor.withValues(alpha: 0.2);
      badgeColor = Colors.orange.shade800;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cuota ${payment.installmentNumber}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '\$${payment.amountUsd.toStringAsFixed(2)} USD',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Vence: ${DateFormatter.toIsoDate(payment.dueDate)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                if (payment.paymentDate != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.successColor),
                  const SizedBox(width: 4),
                  Text(
                    'Pagado: ${DateFormatter.toIsoDate(payment.paymentDate!)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.successColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
            if (payment.paymentMethod != null || payment.receiptRef != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        if (payment.paymentMethod != null) payment.paymentMethod!,
                        if (payment.receiptRef != null) 'Ref: ${payment.receiptRef}',
                      ].join(' • '),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
