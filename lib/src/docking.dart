import 'package:docking/src/docking_buttons_builder.dart';
import 'package:docking/src/drag_over_position.dart';
import 'package:docking/src/internal/widgets/docking_item_widget.dart';
import 'package:docking/src/internal/widgets/docking_tabs_widget.dart';
import 'package:docking/src/layout/docking_layout.dart';
import 'package:docking/src/on_item_close.dart';
import 'package:docking/src/on_item_selection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:multi_split_view/multi_split_view.dart';

/// The docking widget.
class Docking extends StatefulWidget {
  const Docking(
      {Key? key,
      this.layout,
      this.onItemSelection,
      this.onItemClose,
      this.itemCloseInterceptor,
      this.dockingButtonsBuilder,
      this.maximizableItem = false,
      this.maximizableTab = false,
      this.maximizableTabsArea = false,
      this.antiAliasingWorkaround = true,
      this.draggable = true,
      this.focusedItemId})
      : super(key: key);

  final DockingLayout? layout;
  final OnItemSelection? onItemSelection;
  final OnItemClose? onItemClose;
  final ItemCloseInterceptor? itemCloseInterceptor;
  final DockingButtonsBuilder? dockingButtonsBuilder;
  final bool maximizableItem;
  final bool maximizableTab;
  final bool maximizableTabsArea;
  final bool antiAliasingWorkaround;
  final bool draggable;

  /// The id of the globally focused docking item across all panes.
  ///
  /// When provided, each [DockingItemWidget] and [DockingTabsWidget] uses this
  /// to determine whether it owns the focused tab and adjusts its selected tab
  /// visual accordingly — only the pane containing the focused tab shows the
  /// accent highlight.
  final ValueListenable<String?>? focusedItemId;

  @override
  State<StatefulWidget> createState() => _DockingState();
}

/// The [Docking] state.
class _DockingState extends State<Docking> {
  final DragOverPosition _dragOverPosition = DragOverPosition();

  @override
  void initState() {
    super.initState();
    _dragOverPosition.addListener(_forceRebuild);
    widget.layout?.addListener(_forceRebuild);
  }

  @override
  void dispose() {
    super.dispose();
    _dragOverPosition.removeListener(_forceRebuild);
    widget.layout?.removeListener(_forceRebuild);
  }

  @override
  void didUpdateWidget(Docking oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout != widget.layout) {
      oldWidget.layout?.removeListener(_forceRebuild);
      widget.layout?.addListener(_forceRebuild);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.layout != null) {
      if (widget.layout!.maximizedArea != null) {
        List<DockingArea> areas = widget.layout!.layoutAreas();
        List<Widget> children = [];
        for (DockingArea area in areas) {
          if (area != widget.layout!.maximizedArea!) {
            if (area is DockingItem &&
                area.globalKey != null &&
                area.parent != widget.layout?.maximizedArea) {
              // keeping alive other areas
              children.add(ExcludeFocus(
                  child: Offstage(child: _buildArea(context, area))));
            }
          }
        }
        children.add(_buildArea(context, widget.layout!.maximizedArea!));
        return Stack(children: children);
      }
      if (widget.layout!.root != null) {
        return _buildArea(context, widget.layout!.root!);
      }
    }
    return Container();
  }

  Widget _buildArea(BuildContext context, DockingArea area) {
    if (area is DockingItem) {
      return DockingItemWidget(
          key: area.key,
          layout: widget.layout!,
          dragOverPosition: _dragOverPosition,
          draggable: widget.draggable,
          item: area,
          onItemSelection: widget.onItemSelection,
          itemCloseInterceptor: widget.itemCloseInterceptor,
          onItemClose: widget.onItemClose,
          dockingButtonsBuilder: widget.dockingButtonsBuilder,
          maximizable: widget.maximizableItem,
          focusedItemId: widget.focusedItemId);
    } else if (area is DockingRow) {
      return _row(context, area);
    } else if (area is DockingColumn) {
      return _column(context, area);
    } else if (area is DockingTabs) {
      // When a DockingTabs has exactly one child, we render DockingItemWidget instead
      // of DockingTabsWidget to avoid the overhead of a full tab strip for a single tab.
      // The keys use the same area.id but different prefixes (tabs_item_ vs tabs_) so
      // Flutter correctly remounts the widget when the pane transitions between single
      // and multi-tab state — without this, Flutter would try to reuse DockingItemWidget
      // as DockingTabsWidget due to same tree position, causing type mismatch errors.
      if (area.childrenCount == 1) {
        return DockingItemWidget(
            key: ValueKey('tabs_item_${area.id}'),
            layout: widget.layout!,
            dragOverPosition: _dragOverPosition,
            draggable: widget.draggable,
            item: area.childAt(0),
            onItemSelection: widget.onItemSelection,
            itemCloseInterceptor: widget.itemCloseInterceptor,
            onItemClose: widget.onItemClose,
            dockingButtonsBuilder: widget.dockingButtonsBuilder,
            maximizable: widget.maximizableItem,
            focusedItemId: widget.focusedItemId);
      }
      return DockingTabsWidget(
          key: ValueKey('tabs_${area.id}'),
          layout: widget.layout!,
          dragOverPosition: _dragOverPosition,
          draggable: widget.draggable,
          dockingTabs: area,
          onItemSelection: widget.onItemSelection,
          onItemClose: widget.onItemClose,
          itemCloseInterceptor: widget.itemCloseInterceptor,
          dockingButtonsBuilder: widget.dockingButtonsBuilder,
          maximizableTab: widget.maximizableTab,
          maximizableTabsArea: widget.maximizableTabsArea,
          focusedItemId: widget.focusedItemId);
    }
    throw UnimplementedError(
        'Unrecognized runtimeType: ' + area.runtimeType.toString());
  }

  Widget _row(BuildContext context, DockingRow row) {
    List<Widget> children = [];
    row.forEach((child) {
      children.add(_buildArea(context, child));
    });
    return MultiSplitView(
        key: row.key,
        children: children,
        axis: Axis.horizontal,
        controller: row.controller,
        antiAliasingWorkaround: widget.antiAliasingWorkaround);
  }

  Widget _column(BuildContext context, DockingColumn column) {
    List<Widget> children = [];
    column.forEach((child) {
      children.add(_buildArea(context, child));
    });
    return MultiSplitView(
        key: column.key,
        children: children,
        axis: Axis.vertical,
        controller: column.controller,
        antiAliasingWorkaround: widget.antiAliasingWorkaround);
  }

  void _forceRebuild() {
    setState(() {});
  }
}
