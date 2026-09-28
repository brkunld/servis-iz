import 'package:flutter/material.dart';

/// Şirket panelinde hangi listenin gösterildiği.
enum DashboardView { customers, technicians }

/// "Müşteriler | Teknisyenler" geçiş düğmesi.
class ViewModeToggle extends StatelessWidget {
  const ViewModeToggle({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final DashboardView current;
  final ValueChanged<DashboardView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: "Müşteriler",
              icon: Icons.people_outline,
              selected: current == DashboardView.customers,
              duration: const Duration(milliseconds: 300),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              onTap: () => onChanged(DashboardView.customers),
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(
            child: _ToggleButton(
              label: "Teknisyenler",
              icon: Icons.engineering_outlined,
              selected: current == DashboardView.technicians,
              duration: const Duration(milliseconds: 100),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              onTap: () => onChanged(DashboardView.technicians),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.duration,
    required this.borderRadius,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Duration duration;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: borderRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
