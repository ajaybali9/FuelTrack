#!/usr/bin/env node
'use strict';

const fs = require('fs');

function fail(msg) {
  console.error(msg);
  process.exit(1);
}

function main() {
  const inputPath = process.argv[2];
  const outputPath = process.argv[3];
  if (!inputPath || !outputPath) {
    fail('Usage: node ua-tour-analyze.js <input.json> <output.json>');
  }

  let data;
  try {
    data = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  } catch (err) {
    fail(`Failed to read/parse input: ${err.message}`);
  }

  const nodes = data.nodes || [];
  const edges = data.edges || [];
  const layers = data.layers || [];

  if (!Array.isArray(nodes) || !Array.isArray(edges)) {
    fail('Input must contain nodes and edges arrays');
  }

  const nodeById = new Map();
  for (const n of nodes) {
    if (n && n.id) nodeById.set(n.id, n);
  }

  const fanIn = new Map();
  const fanOut = new Map();
  for (const id of nodeById.keys()) {
    fanIn.set(id, 0);
    fanOut.set(id, 0);
  }

  for (const e of edges) {
    if (!e || !e.source || !e.target) continue;
    if (nodeById.has(e.target)) {
      fanIn.set(e.target, (fanIn.get(e.target) || 0) + 1);
    }
    if (nodeById.has(e.source)) {
      fanOut.set(e.source, (fanOut.get(e.source) || 0) + 1);
    }
  }

  const fanInRanking = [...nodeById.keys()]
    .map((id) => ({
      id,
      fanIn: fanIn.get(id) || 0,
      name: nodeById.get(id).name || id,
    }))
    .sort((a, b) => b.fanIn - a.fanIn || a.id.localeCompare(b.id))
    .slice(0, 20);

  const fanOutRanking = [...nodeById.keys()]
    .map((id) => ({
      id,
      fanOut: fanOut.get(id) || 0,
      name: nodeById.get(id).name || id,
    }))
    .sort((a, b) => b.fanOut - a.fanOut || a.id.localeCompare(b.id))
    .slice(0, 20);

  // Entry point candidates
  const ENTRY_NAMES = new Set([
    'index.ts', 'index.js', 'main.ts', 'main.js', 'app.ts', 'app.js',
    'server.ts', 'server.js', 'mod.rs', 'main.go', 'main.py', 'main.rs',
    'manage.py', 'app.py', 'wsgi.py', 'asgi.py', 'run.py', '__main__.py',
    'Application.java', 'Main.java', 'Program.cs', 'config.ru', 'index.php',
    'App.swift', 'Application.kt', 'main.cpp', 'main.c',
    'FuelTrackApp.swift',
  ]);

  const fanOutValues = [...fanOut.values()].sort((a, b) => a - b);
  const fanInValues = [...fanIn.values()].sort((a, b) => a - b);
  const fanOutThreshold =
    fanOutValues.length === 0
      ? 0
      : fanOutValues[Math.floor(fanOutValues.length * 0.9)] || 0;
  const fanInBottomIdx = Math.max(0, Math.floor(fanInValues.length * 0.25) - 1);
  const fanInLowThreshold =
    fanInValues.length === 0 ? 0 : fanInValues[fanInBottomIdx] || 0;

  function depthOfPath(filePath) {
    if (!filePath) return 99;
    const parts = filePath.replace(/^\.\//, '').split('/').filter(Boolean);
    return parts.length - 1;
  }

  const scored = [];
  for (const n of nodes) {
    const id = n.id;
    const name = n.name || '';
    const filePath = n.filePath || '';
    const type = n.type || '';
    let score = 0;

    const isDoc =
      type === 'document' ||
      name.toLowerCase().endsWith('.md') ||
      id.startsWith('document:');
    const isCodeLike =
      type === 'file' ||
      id.startsWith('file:') ||
      /\.(swift|ts|tsx|js|jsx|py|go|rs|java|kt|cs|php|cpp|c|rb)$/i.test(name);

    if (isDoc) {
      if (name === 'README.md' && depthOfPath(filePath) === 0) score += 5;
      else if (name.toLowerCase().endsWith('.md') && depthOfPath(filePath) === 0)
        score += 2;
    }

    if (isCodeLike && !isDoc) {
      if (ENTRY_NAMES.has(name)) score += 3;
      // Also treat *App.swift as entry-like for SwiftUI
      if (/App\.swift$/i.test(name) && !ENTRY_NAMES.has(name)) score += 3;
      const d = depthOfPath(filePath);
      if (d <= 1) score += 1;
      if ((fanOut.get(id) || 0) >= fanOutThreshold && fanOutThreshold > 0)
        score += 1;
      if ((fanIn.get(id) || 0) <= fanInLowThreshold) score += 1;
    }

    if (score > 0) {
      scored.push({
        id,
        score,
        name,
        summary: n.summary || '',
      });
    }
  }

  scored.sort((a, b) => b.score - a.score || a.id.localeCompare(b.id));
  const entryPointCandidates = scored.slice(0, 5);

  // BFS from top code entry point
  const codeEntry =
    scored.find((c) => {
      const n = nodeById.get(c.id);
      if (!n) return false;
      const isDoc =
        n.type === 'document' ||
        (n.name || '').toLowerCase().endsWith('.md') ||
        c.id.startsWith('document:');
      return !isDoc;
    }) || null;

  const importsCallsAdj = new Map();
  for (const e of edges) {
    if (!e || !e.source || !e.target) continue;
    if (e.type !== 'imports' && e.type !== 'calls') continue;
    if (!nodeById.has(e.source) || !nodeById.has(e.target)) continue;
    if (!importsCallsAdj.has(e.source)) importsCallsAdj.set(e.source, []);
    importsCallsAdj.get(e.source).push(e.target);
  }

  const bfsTraversal = {
    startNode: codeEntry ? codeEntry.id : null,
    order: [],
    depthMap: {},
    byDepth: {},
  };

  if (codeEntry) {
    const start = codeEntry.id;
    const visited = new Set([start]);
    const queue = [start];
    bfsTraversal.depthMap[start] = 0;
    bfsTraversal.order.push(start);

    while (queue.length) {
      const cur = queue.shift();
      const depth = bfsTraversal.depthMap[cur];
      const neighbors = importsCallsAdj.get(cur) || [];
      for (const next of neighbors) {
        if (visited.has(next)) continue;
        visited.add(next);
        bfsTraversal.depthMap[next] = depth + 1;
        bfsTraversal.order.push(next);
        queue.push(next);
      }
    }

    for (const [id, depth] of Object.entries(bfsTraversal.depthMap)) {
      const key = String(depth);
      if (!bfsTraversal.byDepth[key]) bfsTraversal.byDepth[key] = [];
      bfsTraversal.byDepth[key].push(id);
    }
  }

  // Non-code inventory
  const nonCodeFiles = {
    documentation: [],
    infrastructure: [],
    data: [],
    config: [],
  };

  for (const n of nodes) {
    const entry = {
      id: n.id,
      name: n.name || n.id,
      type: n.type,
      summary: n.summary || '',
    };
    switch (n.type) {
      case 'document':
        nonCodeFiles.documentation.push(entry);
        break;
      case 'service':
      case 'pipeline':
      case 'resource':
        nonCodeFiles.infrastructure.push(entry);
        break;
      case 'table':
      case 'schema':
      case 'endpoint':
        nonCodeFiles.data.push(entry);
        break;
      case 'config':
        nonCodeFiles.config.push(entry);
        break;
      default: {
        // Heuristic for file-typed docs/configs when typed loosely
        const name = (n.name || '').toLowerCase();
        const fp = (n.filePath || '').toLowerCase();
        if (name.endsWith('.md') || fp.endsWith('.md')) {
          nonCodeFiles.documentation.push(entry);
        } else if (
          name === 'dockerfile' ||
          name === 'docker-compose.yml' ||
          fp.includes('.github/workflows/')
        ) {
          nonCodeFiles.infrastructure.push(entry);
        } else if (
          name === 'package.json' ||
          name === 'package.swift' ||
          name.endsWith('.plist') ||
          name.endsWith('.yml') ||
          name.endsWith('.yaml') ||
          name.endsWith('.toml') ||
          name === '.gitattributes' ||
          name === '.gitignore'
        ) {
          nonCodeFiles.config.push(entry);
        }
        break;
      }
    }
  }

  // Clusters: bidirectional imports/calls pairs, expand
  const bidirPairs = [];
  const edgeKey = (a, b, type) => `${type}|${a}|${b}`;
  const edgeSet = new Set();
  for (const e of edges) {
    if (!e || !e.source || !e.target) continue;
    if (e.type !== 'imports' && e.type !== 'calls') continue;
    if (!nodeById.has(e.source) || !nodeById.has(e.target)) continue;
    edgeSet.add(edgeKey(e.source, e.target, e.type));
  }

  const pairSeen = new Set();
  for (const e of edges) {
    if (!e || !e.source || !e.target) continue;
    if (e.type !== 'imports' && e.type !== 'calls') continue;
    if (!nodeById.has(e.source) || !nodeById.has(e.target)) continue;
    if (e.source === e.target) continue;
    const reverse = edgeKey(e.target, e.source, e.type);
    if (!edgeSet.has(reverse)) continue;
    const a = e.source < e.target ? e.source : e.target;
    const b = e.source < e.target ? e.target : e.source;
    const pk = `${e.type}|${a}|${b}`;
    if (pairSeen.has(pk)) continue;
    pairSeen.add(pk);
    bidirPairs.push([a, b]);
  }

  // Undirected connectivity among imports/calls for expansion counts
  const undirected = new Map();
  function addUndirected(a, b) {
    if (!undirected.has(a)) undirected.set(a, new Set());
    if (!undirected.has(b)) undirected.set(b, new Set());
    undirected.get(a).add(b);
    undirected.get(b).add(a);
  }
  for (const e of edges) {
    if (!e || !e.source || !e.target) continue;
    if (e.type !== 'imports' && e.type !== 'calls') continue;
    if (!nodeById.has(e.source) || !nodeById.has(e.target)) continue;
    if (e.source === e.target) continue;
    addUndirected(e.source, e.target);
  }

  function countInternalEdges(memberSet) {
    let count = 0;
    for (const e of edges) {
      if (!e || !e.source || !e.target) continue;
      if (e.type !== 'imports' && e.type !== 'calls') continue;
      if (memberSet.has(e.source) && memberSet.has(e.target)) count += 1;
    }
    return count;
  }

  const clusters = [];
  const used = new Set();
  for (const [a, b] of bidirPairs) {
    if (used.has(a) || used.has(b)) continue;
    const members = new Set([a, b]);
    let expanded = true;
    while (expanded && members.size < 5) {
      expanded = false;
      const candidates = new Map();
      for (const m of members) {
        for (const nb of undirected.get(m) || []) {
          if (members.has(nb) || used.has(nb)) continue;
          candidates.set(nb, (candidates.get(nb) || 0) + 1);
        }
      }
      const additions = [...candidates.entries()]
        .filter(([, c]) => c >= 2)
        .sort((x, y) => y[1] - x[1] || x[0].localeCompare(y[0]));
      for (const [nb] of additions) {
        if (members.size >= 5) break;
        members.add(nb);
        expanded = true;
      }
    }
    if (members.size < 2) continue;
    for (const m of members) used.add(m);
    clusters.push({
      nodes: [...members].sort(),
      edgeCount: countInternalEdges(members),
    });
  }

  // Fallback: densely connected groups via high mutual neighbors if few bidir pairs
  if (clusters.length < 5) {
    const nodesList = [...nodeById.keys()].filter(
      (id) => (undirected.get(id) || new Set()).size >= 2
    );
    nodesList.sort(
      (a, b) =>
        (undirected.get(b) || new Set()).size -
          (undirected.get(a) || new Set()).size || a.localeCompare(b)
    );
    for (const seed of nodesList) {
      if (clusters.length >= 10) break;
      if (used.has(seed)) continue;
      const neighbors = [...(undirected.get(seed) || [])].filter(
        (n) => !used.has(n)
      );
      if (neighbors.length < 1) continue;
      // Pick up to 4 neighbors that share most connections with seed's neighborhood
      const scoredN = neighbors
        .map((n) => {
          const nSet = undirected.get(n) || new Set();
          let shared = 0;
          for (const x of neighbors) if (nSet.has(x)) shared += 1;
          if (nSet.has(seed)) shared += 1;
          return { n, shared };
        })
        .sort((a, b) => b.shared - a.shared || a.n.localeCompare(b.n));
      const members = new Set([seed]);
      for (const { n } of scoredN) {
        if (members.size >= 5) break;
        members.add(n);
      }
      if (members.size < 2) continue;
      const key = [...members].sort().join('|');
      if (clusters.some((c) => c.nodes.join('|') === key)) continue;
      for (const m of members) used.add(m);
      clusters.push({
        nodes: [...members].sort(),
        edgeCount: countInternalEdges(members),
      });
    }
  }

  clusters.sort(
    (a, b) => b.edgeCount - a.edgeCount || b.nodes.length - a.nodes.length
  );
  const topClusters = clusters.slice(0, 10);

  const nodeSummaryIndex = {};
  for (const n of nodes) {
    nodeSummaryIndex[n.id] = {
      name: n.name || n.id,
      type: n.type || 'unknown',
      summary: n.summary || '',
    };
  }

  const result = {
    scriptCompleted: true,
    entryPointCandidates,
    fanInRanking,
    fanOutRanking,
    bfsTraversal,
    nonCodeFiles,
    clusters: topClusters,
    layers: {
      count: layers.length,
      list: layers.map((l) => ({
        id: l.id,
        name: l.name,
        description: l.description || '',
      })),
    },
    nodeSummaryIndex,
    totalNodes: nodes.length,
    totalEdges: edges.length,
  };

  try {
    fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
  } catch (err) {
    fail(`Failed to write output: ${err.message}`);
  }

  process.exit(0);
}

main();
