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

/// Represents a widget for [DockingItem].
@internal
class DockingItemWidget extends StatefulWidget {
  DockingItemWidget(
      {Key? key,
      required this.layout,
      required this.dragOverPosition,
      required this.item,
      this.onItemSelection,
      this.onItemClose,
      this.itemCloseInterceptor,
      this.dockingButtonsBuilder,
      required this.maximizable,
      required this.draggable,
      this.focusedItemId})
      : super(key: key);

  final DockingLayout layout;
  final DockingItem item;
  final OnItemSelection? onItemSelection;
  final OnItemClose? onItemClose;
  final ItemCloseInterceptor? itemCloseInterceptor;
  final DockingButtonsBuilder? dockingButtonsBuilder;
  final bool maximizable;
  final DragOverPosition dragOverPosition;
  final bool draggable;

  /// The id of the globally focused docking item across all panes.
  ///
  /// Used to suppress the accent highlight on this item's tab when it
  /// is not the globally focused tab.
  final ValueListenable<String?>? focusedItemId;

  @override
  State<StatefulWidget> createState() => DockingItemWidgetState();
}

class DockingItemWidgetState extends State<DockingItemWidget>
    with DraggableConfigMixin {
  DropPosition? _activeDropPosition;

  @override
  void initState() {
    super.initState();
    widget.focusedItemId?.addListener(_onFocusedItemChanged);
  }

  @override
  void dispose() {
    widget.focusedItemId?.removeListener(_onFocusedItemChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DockingItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedItemId != widget.focusedItemId) {
      oldWidget.focusedItemId?.removeListener(_onFocusedItemChanged);
      widget.focusedItemId?.addListener(_onFocusedItemChanged);
    }
  }

  void _onFocusedItemChanged() {
    if (!mounted) return;
    Future.microtask(() {
      if (mounted) setState(() {});
    });
  }

  // true when this item is the globally focused tab
  bool get _thisItemIsFocused {
    final focusedId = widget.focusedItemId?.value;
    if (focusedId == null) return false;
    return widget.item.id == focusedId;
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
    String name = widget.item.name != null ? widget.item.name! : '';
    Widget content = widget.item.widget;
    if (widget.item.globalKey != null) {
      content = KeyedSubtree(child: content, key: widget.item.globalKey);
    }
    List<TabButton>? buttons;
    if (widget.item.buttons != null && widget.item.buttons!.isNotEmpty) {
      buttons = [];
      buttons.addAll(widget.item.buttons!);
    }
    final bool maximizable = widget.item.maximizable != null
        ? widget.item.maximizable!
        : widget.maximizable;
    if (maximizable) {
      if (buttons == null) {
        buttons = [];
      }
      DockingThemeData data = DockingTheme.of(context);
      if (widget.layout.maximizedArea != null &&
          widget.layout.maximizedArea == widget.item) {
        buttons.add(TabButton(
            icon: data.restoreIcon, onPressed: () => widget.layout.restore()));
      } else {
        buttons.add(TabButton(
            icon: data.maximizeIcon,
            onPressed: () => widget.layout.maximizeDockingItem(widget.item)));
      }
    }

    List<TabData> tabs = [
      TabData(
          value: widget.item,
          text: name,
          content: content,
          closable:
              widget.layout.layoutAreas().whereType<DockingItem>().length > 1
                  ? widget.item.closable
                  : false,
          leading: widget.item.leading,
          buttons: buttons,
          draggable: widget.draggable)
    ];
    TabbedViewController controller = TabbedViewController(tabs);

    OnTabSelection? onTabTap;
    if (widget.onItemSelection != null) {
      onTabTap = (int? index) {
        widget.onItemSelection!(widget.item);
      };
    }

    Widget tabbedView = TabbedView(
        tabsAreaButtonsBuilder: _tabsAreaButtonsBuilder,
        onTabSelection: null,
        onTabTap: onTabTap,
        tabCloseInterceptor: _tabCloseInterceptor,
        onTabClose: _onTabClose,
        controller: controller,
        anyDragActive: widget.dragOverPosition,
        selectToEnableButtons: false,
        onDraggableBuild: widget.draggable
            ? (TabbedViewController controller, int tabIndex, TabData tabData) {
                return buildDraggableConfig(
                  dockingDrag: widget.dragOverPosition,
                  tabData: tabData,
                  context: context,
                );
              }
            : null,
        contentBuilder: (context, tabIndex) => ItemContentWrapper(
            listener: _updateActiveDropPosition,
            layout: widget.layout,
            dockingItem: widget.item,
            child: controller.tabs[tabIndex].content!),
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
      data: _thisItemIsFocused
          ? TabbedViewTheme.of(context)
          : _buildNeutralTheme(TabbedViewTheme.of(context)),
      child: clipped,
    );
  }

  bool _onBeforeDropAccept(
      DraggableData source, TabbedViewController target, int newIndex) {
    DockingItem dockingItem = source.tabData.value;
    if (dockingItem != widget.item) {
      // widget.item may be wrapped in a DockingTabs when remove_item.dart
      // preserves the single-child wrapper — targeting the bare DockingItem
      // directly would throw "nested tabbed panels are not allowed".
      // findDockingTabsWithItem resolves the parent DockingTabs if it exists.
      final parentTabs = widget.layout.findDockingTabsWithItem(widget.item.id);
      widget.layout.moveItem(
          draggedItem: dockingItem,
          targetArea: (parentTabs ?? widget.item) as DropArea,
          dropIndex: newIndex);

      // after move, find the pane that now contains the dropped item and
      // select it so the dropped tab becomes active in the destination pane
      widget.layout.selectItemById(dockingItem.id);
      if (widget.onItemSelection != null) {
        widget.onItemSelection!(dockingItem);
      }
    }
    return true;
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

  List<TabButton> _tabsAreaButtonsBuilder(BuildContext context, int tabsCount) {
    if (widget.dockingButtonsBuilder != null) {
      return widget.dockingButtonsBuilder!(context, null, widget.item);
    }
    return [];
  }

  bool _tabCloseInterceptor(int tabIndex) {
    if (widget.itemCloseInterceptor != null) {
      return widget.itemCloseInterceptor!(widget.item);
    }
    return true;
  }

  void _onTabClose(int tabIndex, TabData tabData) {
    widget.layout.removeItem(item: widget.item);
    if (widget.onItemClose != null) {
      widget.onItemClose!(widget.item, null);
    }
  }
}
