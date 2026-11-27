import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:syntrace/features/graph/data/models/graph_models.dart';
import 'package:syntrace/features/graph/presentation/widgets/graph_explorer_painter.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key, this.graphNodes, this.graphEdges});

  final List<GraphNode>? graphNodes;
  final List<GraphEdge>? graphEdges;

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final _transform = TransformationController();
  final _detailLevel = ValueNotifier<int>(0);
  final _search = TextEditingController();
  final Set<NodeType> _types = {};
  List<GraphNode> _nodes = const [];
  List<GraphEdge> _edges = const [];
  Map<String, Offset> _positions = {};
  Size _scene = const Size(400, 400);
  Size? _viewport;
  String? _selectedId;
  String? _draggingId;
  String _query = '';
  bool _fitPending = true;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _readGraph();
  }

  @override
  void didUpdateWidget(covariant GraphScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graphNodes != widget.graphNodes ||
        oldWidget.graphEdges != widget.graphEdges) {
      _readGraph();
    }
  }

  void _readGraph() {
    final byId = <String, GraphNode>{};
    for (final node in widget.graphNodes ?? const <GraphNode>[]) {
      if (node.id.isNotEmpty &&
          node.position.dx.isFinite &&
          node.position.dy.isFinite) {
        byId[node.id] = node;
      }
    }
    _nodes = List.unmodifiable(byId.values);
    _edges = List.unmodifiable(
      (widget.graphEdges ?? const <GraphEdge>[]).where(
        (edge) =>
            byId.containsKey(edge.source.id) &&
            byId.containsKey(edge.target.id),
      ),
    );
    if (!byId.containsKey(_selectedId)) _selectedId = null;
    _draggingId = null;
    if (_nodes.isEmpty) {
      _positions = {};
      _fitPending = true;
      return;
    }
    final minX = _nodes
        .map((n) => n.position.dx)
        .reduce((a, b) => math.min(a, b));
    final minY = _nodes
        .map((n) => n.position.dy)
        .reduce((a, b) => math.min(a, b));
    final maxX = _nodes
        .map((n) => n.position.dx)
        .reduce((a, b) => math.max(a, b));
    final maxY = _nodes
        .map((n) => n.position.dy)
        .reduce((a, b) => math.max(a, b));
    const padding = 130.0;
    _scene = Size(
      math.max(400.0, maxX - minX + padding * 2),
      math.max(400.0, maxY - minY + padding * 2),
    );
    final shift = Offset(
      (_scene.width - (maxX - minX)) / 2 - minX,
      (_scene.height - (maxY - minY)) / 2 - minY,
    );
    _positions = {for (final node in _nodes) node.id: node.position + shift};
    _fitPending = true;
  }

  void _onTransform() {
    final scale = _transform.value.getMaxScaleOnAxis();
    final level = scale >= 0.85
        ? 2
        : scale >= 0.48
        ? 1
        : 0;
    if (_detailLevel.value != level) _detailLevel.value = level;
  }

  List<GraphNode> get _visibleNodes {
    final candidates = _nodes
        .where((node) => _types.isEmpty || _types.contains(node.type))
        .toList(growable: false);
    if (_query.isEmpty) return candidates;
    final matches = candidates
        .where(
          (node) =>
              '${node.label} ${node.subLabel} ${node.id} ${graphTypeLabel(node.type)}'
                  .toLowerCase()
                  .contains(_query),
        )
        .map((node) => node.id)
        .toSet();
    final contextIds = {...matches};
    for (final edge in _edges) {
      if (matches.contains(edge.source.id)) contextIds.add(edge.target.id);
      if (matches.contains(edge.target.id)) contextIds.add(edge.source.id);
    }
    return candidates
        .where((node) => contextIds.contains(node.id))
        .toList(growable: false);
  }

  List<GraphEdge> _visibleEdges(Set<String> ids) => _edges
      .where(
        (edge) => ids.contains(edge.source.id) && ids.contains(edge.target.id),
      )
      .toList(growable: false);

  Set<String> _related(List<GraphEdge> edges, String? id) {
    final result = <String>{};
    if (id == null) return result;
    for (final edge in edges) {
      if (edge.source.id == id) result.add(edge.target.id);
      if (edge.target.id == id) result.add(edge.source.id);
    }
    result.remove(id);
    return result;
  }

  void _setView(Offset sceneCenter, double scale) {
    final viewport = _viewport;
    if (viewport == null || viewport.isEmpty) return;
    final value = scale.clamp(0.05, 3.0).toDouble();
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, value)
      ..setEntry(1, 1, value)
      ..setEntry(2, 2, value)
      ..setEntry(0, 3, viewport.width / 2 - sceneCenter.dx * value)
      ..setEntry(1, 3, viewport.height / 2 - sceneCenter.dy * value);
  }

  void _fit() {
    final viewport = _viewport;
    final nodes = _visibleNodes;
    if (viewport == null || viewport.isEmpty || nodes.isEmpty) return;
    final points = nodes.map((node) => _positions[node.id]!).toList();
    final minX = points.map((p) => p.dx).reduce((a, b) => math.min(a, b));
    final minY = points.map((p) => p.dy).reduce((a, b) => math.min(a, b));
    final maxX = points.map((p) => p.dx).reduce((a, b) => math.max(a, b));
    final maxY = points.map((p) => p.dy).reduce((a, b) => math.max(a, b));
    final scale = math.min(
      viewport.width / (maxX - minX + 180),
      viewport.height / (maxY - minY + 180),
    );
    _setView(
      Offset((minX + maxX) / 2, (minY + maxY) / 2),
      math.min(scale, 1.5),
    );
  }

  void _zoom(double factor) {
    final viewport = _viewport;
    if (viewport == null) return;
    final center = _transform.toScene(viewport.center(Offset.zero));
    _setView(center, _transform.value.getMaxScaleOnAxis() * factor);
  }

  GraphNode? _hit(Offset point, List<GraphNode> nodes) {
    GraphNode? nearest;
    var distance = double.infinity;
    final scale = _transform.value.getMaxScaleOnAxis();
    for (final node in nodes) {
      final d = (_positions[node.id]! - point).distance;
      if (d < distance &&
          d <= math.max(graphNodeRadius(node) + 5, 22 / scale)) {
        nearest = node;
        distance = d;
      }
    }
    return nearest;
  }

  void _select(GraphNode? node) {
    setState(() => _selectedId = node?.id == _selectedId ? null : node?.id);
  }

  void _moveNode(Offset point) {
    final id = _draggingId;
    if (id == null || !_positions.containsKey(id)) return;
    setState(() {
      _positions = {
        ..._positions,
        id: Offset(
          point.dx.clamp(45.0, _scene.width - 45).toDouble(),
          point.dy.clamp(45.0, _scene.height - 45).toDouble(),
        ),
      };
    });
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _detailLevel.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final available = widget.graphNodes != null && widget.graphEdges != null;
    final visible = _visibleNodes;
    final visibleIds = visible.map((n) => n.id).toSet();
    final edges = _visibleEdges(visibleIds);
    GraphNode? selected;
    for (final node in visible) {
      if (node.id == _selectedId) {
        selected = node;
        break;
      }
    }
    final focused = selected;
    final related = _related(edges, focused?.id);
    return AppPageScaffold(
      title: 'Knowledge Graph',
      subtitle: 'Engineering relationships',
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (available && _nodes.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (value) => setState(() {
                      _query = value.trim().toLowerCase();
                      _selectedId = null;
                    }),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search nodes',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _search.clear();
                                setState(() {
                                  _query = '';
                                  _selectedId = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _control(Icons.tune_rounded, 'Filter node types', _showFilters),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${visible.length} nodes  ·  ${edges.length} connections${_query.isNotEmpty || _types.isNotEmpty ? '  ·  Filtered' : ''}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  scheme.surface,
                  scheme.onSurface,
                  dark ? 0.025 : 0.015,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    if (size != _viewport || _fitPending) {
                      _viewport = size;
                      _fitPending = false;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _viewport == size) _fit();
                      });
                    }
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: GraphGridPainter(
                                scheme.onSurface.withValues(
                                  alpha: dark ? 0.075 : 0.085,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (visible.isNotEmpty && available) ...[
                          Positioned.fill(
                            child: InteractiveViewer(
                              transformationController: _transform,
                              constrained: false,
                              boundaryMargin: const EdgeInsets.all(
                                double.infinity,
                              ),
                              minScale: 0.05,
                              maxScale: 3,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (details) => _select(
                                  _hit(details.localPosition, visible),
                                ),
                                onLongPressStart: (details) {
                                  final node = _hit(
                                    details.localPosition,
                                    visible,
                                  );
                                  if (node != null)
                                    setState(() {
                                      _draggingId = node.id;
                                      _selectedId = node.id;
                                    });
                                },
                                onLongPressMoveUpdate: (details) =>
                                    _moveNode(details.localPosition),
                                onLongPressEnd: (_) => _draggingId = null,
                                onLongPressCancel: () => _draggingId = null,
                                child: SizedBox.fromSize(
                                  size: _scene,
                                  child: RepaintBoundary(
                                    child: ValueListenableBuilder<int>(
                                      valueListenable: _detailLevel,
                                      builder: (context, level, child) =>
                                          CustomPaint(
                                            painter: GraphExplorerPainter(
                                              nodes: visible,
                                              edges: edges,
                                              positions: _positions,
                                              selectedId: focused?.id,
                                              relatedIds: related,
                                              scheme: scheme,
                                              detailLevel: level,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Column(
                              children: [
                                _control(
                                  Icons.add_rounded,
                                  'Zoom in',
                                  () => _zoom(1.25),
                                ),
                                const SizedBox(height: 6),
                                _control(
                                  Icons.remove_rounded,
                                  'Zoom out',
                                  () => _zoom(0.8),
                                ),
                                const SizedBox(height: 6),
                                _control(
                                  Icons.center_focus_strong_rounded,
                                  'Fit graph',
                                  _fit,
                                ),
                                const SizedBox(height: 6),
                                _control(
                                  Icons.list_alt_rounded,
                                  'Browse visible nodes',
                                  () => _showNodes(visible),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          Positioned.fill(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.hub_outlined,
                                      size: 44,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      !available
                                          ? 'Knowledge graph unavailable'
                                          : _nodes.isEmpty
                                          ? 'No graph data yet'
                                          : 'No matching nodes',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      !available
                                          ? 'Relationships will appear when graph data is available.'
                                          : _nodes.isEmpty
                                          ? 'There are no relationships to display yet.'
                                          : 'Try another search or change the filters.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (focused != null) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              leading: Icon(
                graphTypeIcon(focused.type),
                color: graphTypeColor(focused.type, dark),
              ),
              title: Text(
                focused.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${graphTypeLabel(focused.type)} · ${related.length} visible neighbours',
              ),
              trailing: TextButton(
                onPressed: () => _showDetails(focused),
                child: const Text('Details'),
              ),
              onTap: () => _showDetails(focused),
            ),
          ] else if (available && visible.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Pinch to zoom · Tap to focus · Hold to move',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _control(IconData icon, String tooltip, VoidCallback action) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: action,
        icon: Icon(icon, size: 21),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }

  Future<void> _showFilters() async {
    final draft = {..._types};
    final present = _nodes.map((n) => n.type).toSet();
    final result = await showModalBottomSheet<Set<NodeType>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => FractionallySizedBox(
          heightFactor: 0.70,
          child: Column(
            children: [
              ListTile(
                title: const Text('Node types'),
                trailing: TextButton(
                  onPressed: () => update(draft.clear),
                  child: const Text('Reset'),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final type in NodeType.values.where(present.contains))
                      CheckboxListTile(
                        title: Text(graphTypeLabel(type)),
                        secondary: Icon(
                          graphTypeIcon(type),
                          color: graphTypeColor(
                            type,
                            Theme.of(context).brightness == Brightness.dark,
                          ),
                        ),
                        value: draft.contains(type),
                        onChanged: (value) => update(() {
                          if (value == true) {
                            draft.add(type);
                          } else {
                            draft.remove(type);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, draft),
                    child: Text(
                      draft.isEmpty ? 'Show all types' : 'Apply filters',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _types
        ..clear()
        ..addAll(result);
      _selectedId = null;
    });
    _fit();
  }

  Future<void> _showNodes(List<GraphNode> nodes) async {
    final picked = await showModalBottomSheet<GraphNode>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.60,
        child: Column(
          children: [
            const ListTile(title: Text('Visible nodes')),
            Expanded(
              child: ListView.builder(
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  final node = nodes[index];
                  return ListTile(
                    leading: Icon(graphTypeIcon(node.type)),
                    title: Text(node.label),
                    subtitle: Text(graphTypeLabel(node.type)),
                    onTap: () => Navigator.pop(context, node),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null || !_positions.containsKey(picked.id))
      return;
    setState(() => _selectedId = picked.id);
    _setView(
      _positions[picked.id]!,
      math.max(1.0, _transform.value.getMaxScaleOnAxis()),
    );
  }

  Future<void> _showDetails(GraphNode node) async {
    final ids = _related(_edges, node.id)..remove(node.id);
    final neighbours = _nodes
        .where((n) => ids.contains(n.id))
        .toList(growable: false);
    final picked = await showModalBottomSheet<GraphNode>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.58,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(
                graphTypeIcon(node.type),
                color: graphTypeColor(
                  node.type,
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              title: Text(node.label),
              subtitle: Text(graphTypeLabel(node.type)),
            ),
            if (node.subLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  node.subLabel,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Connected nodes (${neighbours.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: neighbours.isEmpty
                  ? const Center(child: Text('No connected nodes.'))
                  : ListView.builder(
                      itemCount: neighbours.length,
                      itemBuilder: (context, index) {
                        final other = neighbours[index];
                        return ListTile(
                          leading: Icon(graphTypeIcon(other.type)),
                          title: Text(other.label),
                          subtitle: Text(graphTypeLabel(other.type)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, other),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null || !_positions.containsKey(picked.id))
      return;
    _search.clear();
    setState(() {
      _query = '';
      _types.clear();
      _selectedId = picked.id;
    });
    _setView(
      _positions[picked.id]!,
      math.max(1.0, _transform.value.getMaxScaleOnAxis()),
    );
  }
}
