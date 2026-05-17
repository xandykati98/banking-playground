// ─── App Shell ────────────────────────────────────────────────────────────────
// This file is the agent's canvas. Edit it freely to restructure the UI.
// Rules:
//   - Keep AppShell as a public StatefulWidget with the same constructor signature.
//   - Always keep the PromptModal reachable (e.g. via a FAB or button).
//   - You may import any component from lib/components/current/ or add new ones.
//   - Do NOT import or modify main.dart.

import 'package:flutter/material.dart';

import 'component_props.dart';
import 'layout_model.dart';
import 'prompt_modal.dart';
import 'components/current/app_header.dart';
import 'components/current/account_section.dart';
import 'components/current/balance_section.dart';
import 'components/current/bottom_nav.dart';
import 'components/current/promo_banner.dart';
import 'components/current/quick_actions.dart';
import 'components/current/tab_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.layout,
    required this.onReload,
  });

  final LayoutData layout;
  final VoidCallback onReload;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedTab = 0;
  int _selectedNav = 0;
  bool _balanceVisible = true;

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PromptModal(onPromptComplete: widget.onReload),
    );
  }

  Widget _buildComponent(ComponentData comp) {
    switch (comp.type) {
      case 'AppHeader':
        return AppHeader(
          props: comp.props,
          balanceVisible: _balanceVisible,
          onToggleBalance: () =>
              setState(() => _balanceVisible = !_balanceVisible),
        );
      case 'DashboardTabBar':
        return DashboardTabBar(
          props: comp.props,
          selectedIndex: _selectedTab,
          onTap: (i) => setState(() => _selectedTab = i),
        );
      case 'BalanceSection':
        return BalanceSection(props: comp.props, visible: _balanceVisible);
      case 'QuickActions':
        return QuickActions(props: comp.props);
      case 'PromoBanner':
        return PromoBanner(props: comp.props);
      case 'AccountSection':
        return AccountSection(
            props: comp.props, balanceVisible: _balanceVisible);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final root = layout.rootProps;

    final navComp = layout['bottom_nav'];
    final bodyComps = layout.components
        .where((c) => c.type != 'BottomNavBar')
        .toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: propColor(root, 'scaffoldBackgroundColor', Colors.white),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...bodyComps.map(_buildComponent),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openChat,
          backgroundColor:
              propColor(root, 'fabBackgroundColor', const Color(0xFF6C63FF)),
          tooltip: 'AI Assistant',
          child: Icon(
            Icons.auto_awesome,
            color: propColor(root, 'fabIconColor', Colors.white),
          ),
        ),
        bottomNavigationBar: navComp != null
            ? BottomNavBar(
                props: navComp.props,
                selectedIndex: _selectedNav,
                onTap: (i) => setState(() => _selectedNav = i),
              )
            : null,
      ),
    );
  }
}
