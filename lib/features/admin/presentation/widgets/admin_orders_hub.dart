import 'package:dk_pos/features/admin/presentation/widgets/admin_cash_shifts_panel.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_sales_reports_panel.dart';
import 'package:flutter/material.dart';

/// Раздел «Заказы»: продажи и кассовые смены.
class AdminOrdersHub extends StatefulWidget {
  const AdminOrdersHub({super.key, required this.maxBodyWidth});

  final double maxBodyWidth;

  @override
  State<AdminOrdersHub> createState() => _AdminOrdersHubState();
}

class _AdminOrdersHubState extends State<AdminOrdersHub>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Продажи'),
            Tab(text: 'Кассовые смены'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              AdminSalesReportsPanel(maxBodyWidth: widget.maxBodyWidth),
              AdminCashShiftsPanel(maxBodyWidth: widget.maxBodyWidth),
            ],
          ),
        ),
      ],
    );
  }
}
