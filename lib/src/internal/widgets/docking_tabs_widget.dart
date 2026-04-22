import 'dart:math' as math;

import 'package:docking/src/docking_buttons_builder.dart';
import 'package:docking/src/drag_over_position.dart';
import 'package:docking/src/internal/widgets/draggable_config_mixin.dart';
import 'package:docking/src/internal/widgets/drop/content_wrapper.dart';
import 'package:docking/src/internal/widgets/drop/drop_feedback_widget.dart';
import 'package:docking/src/layout/docking_layout.dart';
import 'package:docking/src/layout/drop_position.dart';
import 'package:docking/src/on_item_close.dart';
import 'package:docking/src/on_item_selection.dart';
import 'package:docking/src/theme/docking_theme.dart';
import 'package:docking/src/theme/docking_theme_data.dart';
import 'package:fluent_ui/fluent_ui.dart' show FluentTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tabbed_view/tabbed_view.dart';

class DockingTabsWidget extends StatefulWidget {
  DockingTabsWidget(
      {Key? key,
      required this.layout,
      required this.dragOverPosition,
      required this.dockingTabs,
      this.onItemSelection,
      this.onItemClose,
      this.itemCloseInterceptor,
      this.dockingButtonsBuilder,
      required this.maximizableTab,
      required this.maximizableTabsArea,
      required this.draggable,
      this.focusedItemId})
      : super(key: key);

  final DockingLayout layout;
  final DockingTabs dockingTabs;
  final OnItemSelection? onItemSelection;
  final OnItemClose? onItemClose;
  final ItemCloseInterceptor? itemCloseInterceptor;
  final DockingButtonsBuilder? dockingButtonsBuilder;
  final bool maximizableTab;
  final bool maximizableTabsArea;
  final DragOverPosition dragOverPosition;
  final bool draggable;

  /// The id of the globally focused docking item across all panes.
  ///
  /// Used to determine whether this pane owns the focused tab so the
  /// selected tab accent highlight is only shown in the focused pane.
  final ValueListenable<String?>? focusedItemId;

  @override
  State<StatefulWidget> createState() => DockingTabsWidgetState();
}

class DockingTabsWidgetState extends State<DockingTabsWidget>
    with DraggableConfigMixin {
  DropPosition? _activeDropPosition;
  late TabbedViewController _controller;

  // TabData objects hold scrollKey and uniqueKey which Flutter uses to
  // maintain scroll position and widget identity across rebuilds.
  // Recreating TabData on every _syncController call would generate new
  // keys, causing TabbedView to remount tab widgets and lose scroll state.
  // Cache keyed by DockingItem identity so the same TabData — and its
  // stable keys — are reused as long as the DockingItem exists in the layout.
  final Map<DockingItem, TabData> _tabCache = {};

  bool get _allowRightEdgeDrop => widget.layout.root is! DockingRow;

  // true when one of this pane's tabs matches the globally focused tab id
  bool get _thisPaneContainsFocusedTab {
    final focusedId = widget.focusedItemId?.value;
    if (focusedId == null) return false;
    for (var i = 0; i < widget.dockingTabs.childrenCount; i++) {
      if (widget.dockingTabs.childAt(i).id == focusedId) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    widget.focusedItemId?.addListener(_onFocusedItemChanged);
    _controller = TabbedViewController([]);
    _syncController();
  }

  @override
  void dispose() {
    widget.focusedItemId?.removeListener(_onFocusedItemChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DockingTabsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedItemId != widget.focusedItemId) {
      oldWidget.focusedItemId?.removeListener(_onFocusedItemChanged);
      widget.focusedItemId?.addListener(_onFocusedItemChanged);
    }
    _syncController();
  }

  void _onFocusedItemChanged() {
    if (!mounted) return;
    Future.microtask(() {
      if (mounted) setState(() {});
    });
  }

  void _syncController() {
    final int totalItems =
        widget.layout.layoutAreas().whereType<DockingItem>().length;
    final int desiredSelectedIndex = math.min(
        widget.dockingTabs.selectedIndex, widget.dockingTabs.childrenCount - 1);

    // build desired tab list, reusing cached TabData by DockingItem identity
    final List<TabData> desired = [];
    widget.dockingTabs.forEach((child) {
      Widget content = child.widget;
      if (child.globalKey != null) {
        content = KeyedSubtree(child: content, key: child.globalKey);
      }

      List<TabButton>? buttons;
      if (child.buttons != null && child.buttons!.isNotEmpty) {
        buttons = []..addAll(child.buttons!);
      }

      final bool maximizable = child.maximizable != null
          ? child.maximizable!
          : widget.maximizableTab;
      if (maximizable) {
        if (buttons == null) buttons = [];
        DockingThemeData data = DockingTheme.of(context);
        if (widget.layout.maximizedArea != null &&
            widget.layout.maximizedArea == child) {
          buttons.add(TabButton(
              icon: data.restoreIcon,
              onPressed: () => widget.layout.restore()));
        } else {
          buttons.add(TabButton(
              icon: data.maximizeIcon,
              onPressed: () => widget.layout.maximizeDockingItem(child)));
        }
      }

      // close button only on the selected tab
      final bool closable = totalItems > 1 ? child.closable : false;

      if (_tabCache.containsKey(child)) {
        // reuse existing TabData — preserves scrollKey and uniqueKey
        final TabData existing = _tabCache[child]!;
        existing.text = child.name != null ? child.name! : '';
        existing.closable = closable;
        existing.buttons = buttons;
        desired.add(existing);
      } else {
        final TabData newTab = TabData(
            value: child,
            text: child.name != null ? child.name! : '',
            content: content,
            closable: closable,
            keepAlive: child.globalKey != null,
            leading: child.leading,
            buttons: buttons,
            draggable: widget.draggable);
        _tabCache[child] = newTab;
        desired.add(newTab);
      }
    });

    // remove stale cache entries
    _tabCache.removeWhere((item, _) => !desired.any((t) => t.value == item));

    // remove tabs from controller that are no longer desired
    final Set<DockingItem> desiredItems =
        desired.map((t) => t.value as DockingItem).toSet();
    for (int i = _controller.tabs.length - 1; i >= 0; i--) {
      final tab = _controller.tabs[i];
      if (!desiredItems.contains(tab.value as DockingItem)) {
        _controller.removeTab(i);
      }
    }

    // insert tabs that are missing from controller, or replace if TabData
    // identity differs — occurs after cross-pane drag where the controller
    // retains the source pane's TabData while the cache has a new instance
    for (int i = 0; i < desired.length; i++) {
      final DockingItem item = desired[i].value as DockingItem;
      final int currentIndex =
          _controller.tabs.indexWhere((t) => t.value == item);
      if (currentIndex == -1) {
        _controller.insertTab(i, desired[i]);
      } else if (!identical(_controller.tabs[currentIndex], desired[i])) {
        _controller.removeTab(currentIndex);
        _controller.insertTab(i, desired[i]);
      }
    }

    // reorder controller tabs to match desired order
    for (int i = 0; i < desired.length; i++) {
      final int current =
          _controller.tabs.indexWhere((t) => t.value == desired[i].value);
      if (current != -1 && current != i) {
        _controller.reorderTab(current, i);
      }
    }

    if (_controller.tabs.isNotEmpty) {
      final int newSelectedIndex =
          desiredSelectedIndex.clamp(0, _controller.tabs.length - 1);

      if (_controller.selectedIndex != newSelectedIndex) {
        _controller.selectedIndex = newSelectedIndex;
      }
    }
  }

  // builds a neutral theme for non-focused panes — selected tab uses the
  // hover style (subtle bg, normal text) instead of accent so only the
  // globally focused pane shows the full accent highlight
  TabbedViewThemeData _buildNeutralTheme(TabbedViewThemeData source) {
    return source.copyWith(
      tab: source.tab.copyWith(
        selectedStatus: source.tab.selectedStatus.copyWith(
          decoration: source.tab.highlightedStatus.decoration,
          fontColor: source.tab.textStyle?.color,
          normalButtonColor: source.tab.highlightedStatus.normalButtonColor,
          hoverButtonColor: source.tab.highlightedStatus.hoverButtonColor,
          disabledButtonColor: Colors.transparent,
          hoverButtonBackground:
              source.tab.highlightedStatus.hoverButtonBackground,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget tabbedView = TabbedView(
        controller: _controller,
        anyDragActive: widget.dragOverPosition,
        tabsAreaButtonsBuilder: _tabsAreaButtonsBuilder,
        selectToEnableButtons: false,
        onTabSelection: (int? index) {
          if (index != null) {
            widget.dockingTabs.selectedIndex = index;
            setState(() {});
          }
        },
        onTabTap: (int? index) {
          if (index != null && widget.onItemSelection != null) {
            widget.onItemSelection!(widget.dockingTabs.childAt(index));
          }
        },
        tabCloseInterceptor: _tabCloseInterceptor,
        onDraggableBuild: widget.draggable
            ? (TabbedViewController controller, int tabIndex, TabData tabData) {
                return buildDraggableConfig(
                  dockingDrag: widget.dragOverPosition,
                  tabData: tabData,
                  context: context,
                );
              }
            : null,
        onTabClose: _onTabClose,
        contentBuilder: (context, tabIndex) => TabsContentWrapper(
            listener: _updateActiveDropPosition,
            layout: widget.layout,
            dockingTabs: widget.dockingTabs,
            allowRightEdgeDrop: _allowRightEdgeDrop,
            child: _controller.tabs[tabIndex].content!),
        onBeforeDropAccept: widget.draggable ? _onBeforeDropAccept : null);

    final Widget clipped = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DropFeedbackWidget(
        dropPosition: widget.draggable && widget.dragOverPosition.enable
            ? _activeDropPosition
            : null,
        accentColor: FluentTheme.of(context).accentColor.lighter,
        child: tabbedView,
      ),
    );

    // TabbedViewTheme is always present in the tree regardless of focus state.
    // Conditionally inserting or removing TabbedViewTheme would change the
    // widget tree structure, causing TabbedView and TabsArea to remount and
    // lose their ScrollController state — resetting the tab strip scroll
    // position to zero on every focus change. Only the theme data is swapped.
    return TabbedViewTheme(
      data: _thisPaneContainsFocusedTab
          ? TabbedViewTheme.of(context)
          : _buildNeutralTheme(TabbedViewTheme.of(context)),
      child: clipped,
    );
  }

  void _updateActiveDropPosition(DropPosition? dropPosition) {
    if (_activeDropPosition != dropPosition) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _activeDropPosition = dropPosition;
          });
        }
      });
    }
  }

  bool _onBeforeDropAccept(
      DraggableData source, TabbedViewController target, int newIndex) {
    DockingItem dockingItem = source.tabData.value;
    widget.layout.moveItem(
        draggedItem: dockingItem,
        targetArea: widget.dockingTabs,
        dropIndex: newIndex);
    // find the dropped item's actual index after layout rebuild
    widget.layout.selectItemById(dockingItem.id);
    return true;
  }

  List<TabButton> _tabsAreaButtonsBuilder(BuildContext context, int tabsCount) {
    List<TabButton> buttons = [];
    if (widget.dockingButtonsBuilder != null) {
      buttons.addAll(
          widget.dockingButtonsBuilder!(context, widget.dockingTabs, null));
    }
    final bool maximizable = widget.dockingTabs.maximizable != null
        ? widget.dockingTabs.maximizable!
        : widget.maximizableTabsArea;
    if (maximizable) {
      DockingThemeData data = DockingTheme.of(context);
      if (widget.layout.maximizedArea != null &&
          widget.layout.maximizedArea == widget.dockingTabs) {
        buttons.add(TabButton(
            icon: data.restoreIcon, onPressed: () => widget.layout.restore()));
      } else {
        buttons.add(TabButton(
            icon: data.maximizeIcon,
            onPressed: () =>
                widget.layout.maximizeDockingTabs(widget.dockingTabs)));
      }
    }
    return buttons;
  }

  bool _tabCloseInterceptor(int tabIndex) {
    if (widget.itemCloseInterceptor != null) {
      return widget.itemCloseInterceptor!(widget.dockingTabs.childAt(tabIndex));
    }
    return true;
  }

  void _onTabClose(int tabIndex, TabData tabData) {
    DockingItem dockingItem = widget.dockingTabs.childAt(tabIndex);
    final DockingTabs sourcePane = widget.dockingTabs;
    widget.layout.removeItem(item: dockingItem);
    if (widget.onItemClose != null) {
      widget.onItemClose!(dockingItem, sourcePane);
    }
  }
}
