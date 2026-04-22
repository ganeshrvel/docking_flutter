import 'package:docking/docking.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Colors;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Scaffold;
import 'package:system_theme/system_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemTheme.accentColor.load();
  runApp(const DockingExampleApp());
}

// Root app widget — owns theme mode and OS accent color state.
// Listens to SystemTheme.onChange to react to OS accent color changes live.
class DockingExampleApp extends StatefulWidget {
  const DockingExampleApp({Key? key}) : super(key: key);

  @override
  State<DockingExampleApp> createState() => _DockingExampleAppState();
}

class _DockingExampleAppState extends State<DockingExampleApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  AccentColor _accentColor = SystemTheme.accentColor.accent.toAccentColor();

  @override
  void initState() {
    super.initState();
    // keep accent color in sync when the user changes it in OS settings
    SystemTheme.onChange.listen((color) {
      if (mounted) {
        setState(() {
          _accentColor = color.accent.toAccentColor();
        });
      }
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  FluentThemeData _buildFluentTheme(Brightness brightness) {
    return FluentThemeData(
      brightness: brightness,
      accentColor: _accentColor,
      visualDensity: VisualDensity.standard,
      focusTheme: const FocusThemeData(glowFactor: 0),
      // Todo (important): if we dont set this the tooltip will default to 1 second
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 500),
        preferBelow: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      title: 'Docking example',
      themeMode: _themeMode,
      theme: _buildFluentTheme(Brightness.light),
      darkTheme: _buildFluentTheme(Brightness.dark),
      home: DockingExamplePage(
        onToggleTheme: _toggleTheme,
        themeMode: _themeMode,
        accentColor: _accentColor,
      ),
    );
  }
}

// Page widget — owns docking layout and all theme color derivations.
class DockingExamplePage extends StatefulWidget {
  const DockingExamplePage({
    Key? key,
    required this.onToggleTheme,
    required this.themeMode,
    required this.accentColor,
  }) : super(key: key);

  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final AccentColor accentColor;

  @override
  DockingExamplePageState createState() => DockingExamplePageState();
}

class DockingExamplePageState extends State<DockingExamplePage> {
  late DockingLayout _layout;
  int _newTabCount = 0;

  bool get _isDark => widget.themeMode == ThemeMode.dark;

  // Fluent UI ResourceDictionary — provides semantic color tokens for
  // dark and light mode, matching the Windows 11 design system.
  ResourceDictionary get _res => _isDark
      ? const ResourceDictionary.dark()
      : const ResourceDictionary.light();

  // outermost background — window chrome, sidebar, titlebar
  Color get _mortar => _res.solidBackgroundFillColorBase;

  // pane content background — inside each docking pane
  Color get _paneBg => _res.layerOnMicaBaseAltFillColorTertiary;

  // tab strip background — the row containing tab headers
  Color get _stripBg => _isDark
      ? _res.layerFillColorDefault
      : _res.solidBackgroundFillColorSecondary;

  // OS accent color resolved to correct shade for current brightness
  Color get _accent => widget.accentColor.defaultBrushFor(
        _isDark ? Brightness.dark : Brightness.light,
      );

  // semi-transparent accent for tab selection backgrounds and drag overlays
  Color get _accentTint => _accent.withValues(alpha: 0.2);

  // unselected tab text and icon color
  Color get _tabNorm => _res.textFillColorSecondary;

  // selected tab text and icon color
  Color get _tabSel => _res.textFillColorPrimary;

  // border color for the new tab button and menu borders
  Color get _borderColor => _navIconColor;

  // subtle hover background for unselected tabs
  Color get _highlightBg => _res.subtleFillColorSecondary;

  // nav icon color — arrows, info icon and + button border/icon
  Color get _navIconColor => _tabNorm.withValues(alpha: 0.70);

  // new tab button — bordered rounded square with accent hover state
  TabButton _addTabButton({required VoidCallback onPressed}) {
    return TabButton(
      icon: IconProvider.data(CupertinoIcons.add),
      toolTip: 'New Tab',
      color: _navIconColor,
      hoverColor: _accent,
      padding: const EdgeInsets.all(4),
      background: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: _borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      hoverBackground: BoxDecoration(
        color: _accentTint,
        border: Border.all(color: _accent, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      onPressed: onPressed,
    );
  }

  // leading icon shown to the left of each tab label
  Widget _tabLeading(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Icon(icon, size: 15, color: color),
    );
  }

  // creates a DockingItem with keepAlive=true so tab content state
  // (e.g. scroll position, counter) persists across tab switches
  DockingItem _item({
    required String id,
    required String name,
    required Widget widget,
    required IconData icon,
  }) {
    return DockingItem(
      id: id,
      name: name,
      widget: widget,
      keepAlive: true,
      leading: (context, status) {
        final color = status == TabStatus.selected
            ? _accent
            : _tabSel.withValues(alpha: 0.6);
        return _tabLeading(icon, color);
      },
    );
  }

  TabbedViewThemeData _buildTheme() {
    // shared decoration constants
    const tabBorderRadius = BorderRadius.all(Radius.circular(8));
    final closeButtonHoverBg = BoxDecoration(
      color: _tabSel.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
    );
    const transparentBg = BoxDecoration(color: Colors.transparent);
    final tabSelectedBg = BoxDecoration(
      color: _accentTint,
      borderRadius: tabBorderRadius,
    );
    final tabHighlightBg = BoxDecoration(
      color: _highlightBg,
      borderRadius: tabBorderRadius,
    );
    final tabDraggingBg = BoxDecoration(
      color: _accentTint,
      borderRadius: tabBorderRadius,
    );

    final theme = TabbedViewThemeData.minimalist();

    // tab strip
    theme.tabsArea.color = _stripBg;
    theme.tabsArea.border = const Border();
    theme.tabsArea.dropColor = _accent.withValues(alpha: 0.18);
    theme.tabsArea.equalHeights = EqualHeights.all;
    theme.tabsArea.initialGap = 0;
    theme.tabsArea.middleGap = 4;
    theme.tabsArea.normalButtonColor = _tabNorm;
    theme.tabsArea.menuIcon = IconProvider.data(CupertinoIcons.chevron_down);
    theme.tabsArea.hoverButtonBackground = transparentBg;
    theme.tabsArea.buttonIconSize = 16;
    theme.tabsArea.hoverButtonColor = _accent;
    // transparent so the strip bg shows through without double-painting
    theme.tabsArea.buttonsAreaDecoration = transparentBg;
    theme.tabsArea.buttonsAreaPadding =
        const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    theme.tabsArea.disabledButtonColor = _tabNorm;
    theme.tabsArea.disabledButtonBackground = transparentBg;
    theme.tabsArea.tabWidth = 130;
    theme.tabsArea.navIconColor = _navIconColor;

    // tab pill — base style for all states
    theme.tab.textStyle = TextStyle(
      fontSize: 13,
      color: _tabSel.withValues(alpha: 0.6),
    );
    theme.tab.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    theme.tab.paddingWithoutButton =
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    theme.tab.buttonsOffset = 2;
    // vertical margin creates breathing room between strip edge and tab pill
    theme.tab.margin = const EdgeInsets.symmetric(vertical: 8);
    theme.tab.decoration = const BoxDecoration(
      color: Colors.transparent,
      borderRadius: tabBorderRadius,
    );
    theme.tab.draggingDecoration = tabDraggingBg;
    theme.tab.draggingOpacity = 0.85;
    theme.tab.buttonIconSize = 13;

    // close/action buttons inside tab pill — invisible until selected
    theme.tab.normalButtonColor = Colors.transparent;
    theme.tab.hoverButtonColor = Colors.transparent;
    theme.tab.disabledButtonColor = Colors.transparent;
    theme.tab.hoverButtonBackground = transparentBg;
    theme.tab.buttonPadding = const EdgeInsets.all(2);

    // selected tab — accent tint bg, accent text, visible close button
    theme.tab.selectedStatus.decoration = tabSelectedBg;
    theme.tab.selectedStatus.fontColor = _accent;
    theme.tab.selectedStatus.normalButtonColor =
        _tabNorm.withValues(alpha: 0.6);
    theme.tab.selectedStatus.hoverButtonColor = _tabSel;
    theme.tab.selectedStatus.disabledButtonColor =
        _tabNorm.withValues(alpha: 0.2);
    theme.tab.selectedStatus.hoverButtonBackground = closeButtonHoverBg;

    // hovered unselected tab — subtle bg tint, close button visible
    theme.tab.highlightedStatus.decoration = tabHighlightBg;
    theme.tab.highlightedStatus.normalButtonColor =
        _tabNorm.withValues(alpha: 0.4);
    theme.tab.highlightedStatus.hoverButtonColor =
        _tabNorm.withValues(alpha: 0.7);
    theme.tab.highlightedStatus.disabledButtonColor = Colors.transparent;
    theme.tab.highlightedStatus.hoverButtonBackground = closeButtonHoverBg;

    // content area below the tab strip
    theme.contentArea.decoration = BoxDecoration(color: _paneBg);
    theme.contentArea.decorationNoTabsArea = BoxDecoration(color: _paneBg);
    theme.contentArea.padding = EdgeInsets.zero;

    // overflow dropdown menu
    theme.menu.color = _paneBg;
    theme.menu.border = Border.all(color: _borderColor, width: 1);
    theme.menu.textStyle = TextStyle(fontSize: 12, color: _tabSel);
    theme.menu.hoverColor = _accentTint;
    theme.menu.blur = false;
    theme.menu.padding = EdgeInsets.zero;
    theme.menu.menuItemPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

    return theme;
  }

  @override
  void initState() {
    super.initState();
    _layout = DockingLayout(
      root: DockingRow([
        DockingTabs([
          _item(
              id: 'left_1',
              name: 'Home',
              widget: const TabContentWidget(label: 'Left — Home'),
              icon: CupertinoIcons.folder),
          _item(
              id: 'left_2',
              name: 'Documents',
              widget: const TabContentWidget(label: 'Left — Documents'),
              icon: CupertinoIcons.folder),
          _item(
              id: 'left_3',
              name: 'Downloads',
              widget: const TabContentWidget(label: 'Left — Downloads'),
              icon: CupertinoIcons.folder),
          _item(
              id: 'left_4',
              name: '1',
              widget: const TabContentWidget(label: 'Left — Tab 1'),
              icon: CupertinoIcons.folder),
          // long names to verify tab label truncation behavior
          _item(
              id: 'left_5',
              name: 'Very Long Folder Name That Should Truncate',
              widget: const TabContentWidget(
                  label: 'Left — Very Long Folder Name That Should Truncate'),
              icon: CupertinoIcons.folder),
          _item(
              id: 'left_6',
              name: 'Another Extremely Long Tab Name For Testing Ellipsis',
              widget: const TabContentWidget(
                  label:
                      'Left — Another Extremely Long Tab Name For Testing Ellipsis'),
              icon: CupertinoIcons.folder),
        ], id: 'left_pane', minimalSize: 200),
        DockingTabs([
          _item(
              id: 'right_1',
              name: 'Android',
              widget: const TabContentWidget(label: 'Right — Android'),
              icon: CupertinoIcons.folder),
          _item(
              id: 'right_2',
              name: 'DCIM',
              widget: const TabContentWidget(label: 'Right — DCIM'),
              icon: CupertinoIcons.folder),
          _item(
              id: 'right_3',
              name: 'Pictures',
              widget: const TabContentWidget(label: 'Right — Pictures'),
              icon: CupertinoIcons.folder),
          _item(
              id: 'right_4',
              name: 'Music',
              widget: const TabContentWidget(label: 'Right — Music'),
              icon: CupertinoIcons.folder),
        ], id: 'right_pane', minimalSize: 200),
      ], id: 'root_row'),
    );
  }

  // prevents closing the last remaining tab in the layout
  bool _onCloseInterceptor(DockingItem item) {
    final totalItems = _layout.layoutAreas().whereType<DockingItem>().length;
    return totalItems > 1;
  }

  // scrolls to newly created tab after layout rebuild completes
  void _scrollToNewTab(String newId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final areas = _layout.layoutAreas().whereType<DockingTabs>();
      for (final area in areas) {
        for (int i = 0; i < area.childrenCount; i++) {
          if (area.childAt(i).id == newId) {
            area.selectedIndex = i;
            setState(() {});
            return;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mortar,
      body: Row(
        children: [
          _MockSidebar(isDark: _isDark, mortar: _mortar, res: _res),
          Expanded(
            child: Column(
              children: [
                // titlebar row
                Container(
                  height: 40,
                  color: _mortar,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Text(
                        'OpenMTP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _res.textFillColorSecondary,
                        ),
                      ),
                      const Spacer(),
                      // theme toggle button
                      GestureDetector(
                        onTap: widget.onToggleTheme,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: _res.subtleFillColorSecondary,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isDark
                                    ? CupertinoIcons.sun_max
                                    : CupertinoIcons.moon,
                                size: 13,
                                color: _tabNorm,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isDark ? 'Light' : 'Dark',
                                style: TextStyle(fontSize: 12, color: _tabNorm),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // docking area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: MultiSplitViewTheme(
                      data: MultiSplitViewThemeData(
                        dividerThickness: 8,
                        dividerPainter: DividerPainters.background(
                          color: _mortar,
                          highlightedColor: _mortar,
                        ),
                      ),
                      child: TabbedViewTheme(
                        data: _buildTheme(),
                        child: Docking(
                          layout: _layout,
                          draggable: true,
                          maximizableItem: false,
                          maximizableTab: false,
                          maximizableTabsArea: false,
                          itemCloseInterceptor: _onCloseInterceptor,
                          dockingButtonsBuilder:
                              (context, dockingTabs, dockingItem) {
                            if (dockingTabs != null) {
                              return [
                                _addTabButton(onPressed: () {
                                  final newId =
                                      'new_${DateTime.now().millisecondsSinceEpoch}';
                                  _newTabCount++;
                                  final newName = 'New Tab $_newTabCount';
                                  _layout.addItemOn(
                                    newItem: _item(
                                      id: newId,
                                      name: newName,
                                      widget: TabContentWidget(label: newName),
                                      icon: CupertinoIcons.folder,
                                    ),
                                    targetArea: dockingTabs,
                                    dropIndex: dockingTabs.childrenCount,
                                  );
                                  _scrollToNewTab(newId);
                                }),
                              ];
                            }
                            if (dockingItem != null) {
                              return [
                                _addTabButton(onPressed: () {
                                  final newId =
                                      'new_${DateTime.now().millisecondsSinceEpoch}';
                                  _newTabCount++;
                                  final newName = 'New Tab $_newTabCount';
                                  final parentTabs = _layout
                                      .findDockingTabsWithItem(dockingItem.id);
                                  _layout.addItemOn(
                                    newItem: _item(
                                      id: newId,
                                      name: newName,
                                      widget: TabContentWidget(label: newName),
                                      icon: CupertinoIcons.folder,
                                    ),
                                    targetArea:
                                        (parentTabs ?? dockingItem) as DropArea,
                                    dropIndex: parentTabs != null
                                        ? parentTabs.childrenCount
                                        : 1,
                                  );
                                  _scrollToNewTab(newId);
                                }),
                              ];
                            }
                            return [];
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// mock sidebar — simulates the favorites panel in the real app
class _MockSidebar extends StatelessWidget {
  const _MockSidebar({
    required this.isDark,
    required this.mortar,
    required this.res,
  });

  final bool isDark;
  final Color mortar;
  final ResourceDictionary res;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      color: mortar,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 6),
            child: Text(
              'Favorites',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: res.textFillColorTertiary,
              ),
            ),
          ),
          _SidebarItem(
              label: 'Home',
              icon: CupertinoIcons.house,
              active: true,
              res: res),
          _SidebarItem(
              label: 'Desktop',
              icon: CupertinoIcons.desktopcomputer,
              active: false,
              res: res),
          _SidebarItem(
              label: 'Downloads',
              icon: CupertinoIcons.arrow_down_to_line,
              active: false,
              res: res),
          _SidebarItem(
              label: 'Documents',
              icon: CupertinoIcons.folder,
              active: false,
              res: res),
          _SidebarItem(
              label: 'Pictures',
              icon: CupertinoIcons.photo,
              active: false,
              res: res),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.res,
  });

  final String label;
  final IconData icon;
  final bool active;
  final ResourceDictionary res;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: active ? res.subtleFillColorSecondary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: active
                  ? res.textFillColorPrimary
                  : res.textFillColorSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: active
                    ? res.textFillColorPrimary
                    : res.textFillColorSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// tab content widget — stateful with a counter to verify keepAlive behavior.
// AutomaticKeepAliveClientMixin ensures state survives tab switches when
// the parent DockingItem has keepAlive=true.
class TabContentWidget extends StatefulWidget {
  const TabContentWidget({Key? key, required this.label}) : super(key: key);

  final String label;

  @override
  State<TabContentWidget> createState() => _TabContentWidgetState();
}

class _TabContentWidgetState extends State<TabContentWidget>
    with AutomaticKeepAliveClientMixin {
  int _counter = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final textColor = FluentTheme.of(context).resources.textFillColorPrimary;
    final accentColor = FluentTheme.of(context).accentColor.lighter;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: TextStyle(fontSize: 13, color: textColor),
          ),
          const SizedBox(height: 16),
          Text(
            '$_counter',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _counter++),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                border: Border.all(color: accentColor, width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Increment',
                style: TextStyle(fontSize: 13, color: accentColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
