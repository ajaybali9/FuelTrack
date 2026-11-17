#!/usr/bin/env node
/**
 * Structural architecture analysis for understand-anything layer assignment.
 * Usage: node ua-arch-analyze.js <input.json> <output.json>
 */
"use strict";

const fs = require("fs");
const path = require("path");

function fail(msg) {
  process.stderr.write(String(msg) + "\n");
  process.exit(1);
}

function loadJson(p) {
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch (e) {
    fail(`Failed to read/parse ${p}: ${e.message}`);
  }
}

function dirnameOf(filePath) {
  const i = filePath.lastIndexOf("/");
  return i === -1 ? "" : filePath.slice(0, i);
}

function commonPrefix(paths) {
  if (!paths.length) return "";
  const split = paths.map((p) => p.split("/").filter(Boolean));
  const first = split[0];
  let end = 0;
  for (; end < first.length; end++) {
    const seg = first[end];
    if (!split.every((parts) => parts[end] === seg)) break;
  }
  // Only treat as directory prefix if all paths share directories (not files)
  // and there is remaining path after prefix for grouping
  if (end === 0) return "";
  // If prefix consumes entire path for some files that are at root of that prefix, still OK
  const prefix = first.slice(0, end).join("/");
  // Verify every path starts with prefix + /
  const withSlash = prefix + "/";
  if (!paths.every((p) => p === prefix || p.startsWith(withSlash))) return "";
  return withSlash;
}

const DIR_PATTERNS = [
  [["routes", "api", "controllers", "endpoints", "handlers", "routers", "blueprints", "serializers", "controller"], "api"],
  [["services", "core", "lib", "domain", "logic", "internal", "signals", "mailers", "jobs", "channels", "composables"], "service"],
  [["models", "db", "data", "persistence", "repository", "entities", "migrations", "entity", "sql", "database", "schema"], "data"],
  [["components", "views", "pages", "ui", "layouts", "screens"], "ui"],
  [["middleware", "plugins", "interceptors", "guards"], "middleware"],
  [["utils", "helpers", "common", "shared", "tools", "templatetags", "pkg"], "utility"],
  [["config", "constants", "env", "settings", "management", "commands"], "config"],
  [["__tests__", "test", "tests", "spec", "specs"], "test"],
  [["types", "interfaces", "schemas", "contracts", "dtos", "dto", "request", "response"], "types"],
  [["hooks"], "hooks"],
  [["store", "state", "reducers", "actions", "slices"], "state"],
  [["assets", "static", "public"], "assets"],
  [["cmd", "bin"], "entry"],
  [["docs", "documentation", "wiki"], "documentation"],
  [["deploy", "deployment", "infra", "infrastructure", "k8s", "kubernetes", "helm", "charts", "terraform", "tf", "docker"], "infrastructure"],
  [[".github", ".gitlab", ".circleci"], "ci-cd"],
  [["theme"], "ui"],
  [["support"], "utility"],
  [["scripts"], "test"],
  [["resources"], "assets"],
];

function matchDirPattern(groupName) {
  const lower = groupName.toLowerCase();
  const segments = lower.split(/[\/._-]+/).filter(Boolean);
  for (const [names, label] of DIR_PATTERNS) {
    if (names.includes(lower) || segments.some((s) => names.includes(s))) return label;
  }
  return null;
}

function matchFilePattern(filePath, name) {
  const base = name || path.basename(filePath);
  const lower = filePath.toLowerCase();
  if (
    /\.(test|spec)\.[^.]+$/i.test(base) ||
    /^test_.*\.py$/i.test(base) ||
    /_test\.go$/i.test(base) ||
    /Test\.java$/i.test(base) ||
    /_spec\.rb$/i.test(base) ||
    /Test\.php$/i.test(base) ||
    /Tests\.cs$/i.test(base) ||
    /-smoke\.swift$/i.test(base)
  )
    return "test";
  if (/\.d\.ts$/i.test(base)) return "types";
  if (base === "index.ts" || base === "index.js" || base === "__init__.py") return "entry";
  if (base === "manage.py" && !filePath.includes("/")) return "entry";
  if (base === "wsgi.py" || base === "asgi.py") return "config";
  if (base === "main.go" && /(?:^|\/)cmd\//.test(filePath)) return "entry";
  if ((base === "main.rs" || base === "lib.rs") && /(?:^|\/)src\//.test(filePath)) return "entry";
  if (base === "Application.java" || base === "Program.cs") return "entry";
  if (base === "config.ru") return "entry";
  if (["Cargo.toml", "go.mod", "Gemfile", "pom.xml", "build.gradle", "composer.json", "Package.swift"].includes(base))
    return "config";
  if (/^Dockerfile/i.test(base) || /^docker-compose\./i.test(base)) return "infrastructure";
  if (/\.tf$/i.test(base) || /\.tfvars$/i.test(base)) return "infrastructure";
  if (/(?:^|\/)\.github\/workflows\//.test(lower) || base === ".gitlab-ci.yml" || base === "Jenkinsfile")
    return "ci-cd";
  if (/\.sql$/i.test(base)) return "data";
  if (/\.(graphql|gql|proto)$/i.test(base)) return "types";
  if (/\.(md|rst)$/i.test(base)) return "documentation";
  if (base === "Makefile") return "infrastructure";
  if (base === "xtool.yml" || base === "Info.plist") return "config";
  if (/\.csv$/i.test(base)) return "data";
  if (/App\.swift$/i.test(base) || /FuelTrackApp\.swift$/i.test(base)) return "entry";
  return null;
}

function main() {
  const inputPath = process.argv[2];
  const outputPath = process.argv[3];
  if (!inputPath || !outputPath) fail("Usage: node ua-arch-analyze.js <input.json> <output.json>");

  const input = loadJson(inputPath);
  const fileNodes = input.fileNodes || [];
  const importEdges = input.importEdges || [];
  const allEdges = input.allEdges || [];

  if (!Array.isArray(fileNodes) || fileNodes.length === 0) fail("fileNodes must be a non-empty array");

  const idToNode = new Map();
  for (const n of fileNodes) {
    if (!n.id || !n.filePath) fail(`Invalid file node: ${JSON.stringify(n)}`);
    idToNode.set(n.id, n);
  }

  const paths = fileNodes.map((n) => n.filePath);
  let prefix = commonPrefix(paths);
  // For mixed roots (Sources/, Scripts/, docs/), common prefix is often empty — good
  // But if everything is under Sources/FuelTrack/, we want group by Models/Services/Views
  // Adjust: if prefix is Sources/ only and next segments diverge, group by second segment under Sources
  // Manual refinement: if >50% under Sources/<Module>/, use Sources/<Module>/ as prefix
  const underSources = paths.filter((p) => p.startsWith("Sources/"));
  if (underSources.length >= fileNodes.length * 0.5) {
    const modulePrefix = commonPrefix(underSources);
    // e.g. Sources/FuelTrack/
    if (modulePrefix && modulePrefix.split("/").filter(Boolean).length >= 2) {
      // Group non-Sources files by their top-level; Sources files by first segment after module prefix
      prefix = modulePrefix; // special handling below
    }
  }

  const directoryGroups = {};
  function addToGroup(group, id) {
    if (!directoryGroups[group]) directoryGroups[group] = [];
    directoryGroups[group].push(id);
  }

  const flatOnly = paths.every((p) => !p.includes("/"));
  if (flatOnly) {
    for (const n of fileNodes) {
      const fp = n.filePath;
      let g = "other";
      if (/\.(test|spec)\./i.test(fp) || /test_/i.test(fp)) g = "test";
      else if (/\.config\./i.test(fp) || /config/i.test(fp)) g = "config";
      else if (/\.(md|rst)$/i.test(fp)) g = "docs";
      else g = path.extname(fp).slice(1) || "other";
      addToGroup(g, n.id);
    }
  } else {
    for (const n of fileNodes) {
      const fp = n.filePath;
      let group;
      if (prefix && (fp === prefix.slice(0, -1) || fp.startsWith(prefix))) {
        const rest = fp.startsWith(prefix) ? fp.slice(prefix.length) : "";
        if (!rest || !rest.includes("/")) {
          // file directly under prefix (e.g. Sources/FuelTrack/FuelTrackApp.swift)
          group = rest ? "_root" : "_root";
        } else {
          group = rest.split("/")[0];
        }
      } else {
        // outside prefix
        const parts = fp.split("/");
        group = parts.length > 1 ? parts[0] : "root";
      }
      addToGroup(group, n.id);
    }
  }

  // Node type grouping
  const nodeTypeGroups = {};
  for (const n of fileNodes) {
    const t = n.type || "file";
    if (!nodeTypeGroups[t]) nodeTypeGroups[t] = [];
    nodeTypeGroups[t].push(n.id);
  }

  // Import adjacency
  const fileFanOut = {};
  const fileFanIn = {};
  for (const n of fileNodes) {
    fileFanOut[n.id] = 0;
    fileFanIn[n.id] = 0;
  }
  const importAdj = {};
  for (const e of importEdges) {
    if (e.type && e.type !== "imports") continue;
    if (!idToNode.has(e.source) || !idToNode.has(e.target)) continue;
    fileFanOut[e.source] = (fileFanOut[e.source] || 0) + 1;
    fileFanIn[e.target] = (fileFanIn[e.target] || 0) + 1;
    if (!importAdj[e.source]) importAdj[e.source] = [];
    importAdj[e.source].push(e.target);
  }

  // Map id -> group
  const idToGroup = {};
  for (const [g, ids] of Object.entries(directoryGroups)) {
    for (const id of ids) idToGroup[id] = g;
  }

  // Inter-group imports
  const interMap = {};
  const intraStats = {};
  for (const g of Object.keys(directoryGroups)) {
    intraStats[g] = { internalEdges: 0, totalEdges: 0 };
  }
  for (const e of importEdges) {
    if (e.type && e.type !== "imports") continue;
    const fg = idToGroup[e.source];
    const tg = idToGroup[e.target];
    if (!fg || !tg) continue;
    if (fg === tg) {
      intraStats[fg].internalEdges++;
      intraStats[fg].totalEdges++;
    } else {
      const key = `${fg}\0${tg}`;
      interMap[key] = (interMap[key] || 0) + 1;
      intraStats[fg].totalEdges++;
      intraStats[tg].totalEdges++;
    }
  }
  const interGroupImports = Object.entries(interMap).map(([k, count]) => {
    const [from, to] = k.split("\0");
    return { from, to, count };
  });
  const intraGroupDensity = {};
  for (const [g, s] of Object.entries(intraStats)) {
    intraGroupDensity[g] = {
      internalEdges: s.internalEdges,
      totalEdges: s.totalEdges,
      density: s.totalEdges === 0 ? 0 : s.internalEdges / s.totalEdges,
    };
  }

  // Cross-category edges
  const crossMap = {};
  for (const e of allEdges) {
    const sn = idToNode.get(e.source);
    const tn = idToNode.get(e.target);
    if (!sn || !tn) continue;
    const fromType = sn.type || "file";
    const toType = tn.type || "file";
    if (fromType === toType && fromType === "file" && (e.type === "imports" || !e.type)) continue;
    const edgeType = e.type || "related";
    const key = `${fromType}\0${toType}\0${edgeType}`;
    crossMap[key] = (crossMap[key] || 0) + 1;
  }
  const crossCategoryEdges = Object.entries(crossMap).map(([k, count]) => {
    const [fromType, toType, edgeType] = k.split("\0");
    return { fromType, toType, edgeType, count };
  });

  // Pattern matches
  const patternMatches = {};
  for (const g of Object.keys(directoryGroups)) {
    const m = matchDirPattern(g);
    if (m) patternMatches[g] = m;
    else {
      // try file-level majority
      const ids = directoryGroups[g];
      const counts = {};
      for (const id of ids) {
        const n = idToNode.get(id);
        const fp = matchFilePattern(n.filePath, n.name);
        if (fp) counts[fp] = (counts[fp] || 0) + 1;
      }
      const best = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
      if (best) patternMatches[g] = best[0];
    }
  }

  // Deployment topology
  const infraFiles = [];
  let hasDockerfile = false,
    hasCompose = false,
    hasK8s = false,
    hasTerraform = false,
    hasCI = false;
  for (const n of fileNodes) {
    const fp = n.filePath;
    const base = path.basename(fp);
    if (/^Dockerfile/i.test(base)) {
      hasDockerfile = true;
      infraFiles.push(fp);
    }
    if (/^docker-compose/i.test(base)) {
      hasCompose = true;
      infraFiles.push(fp);
    }
    if (/(?:^|\/)(k8s|kubernetes|helm|charts)\//i.test(fp) || /\.ya?ml$/i.test(fp) && /deployment|service|ingress/i.test(base)) {
      // soft
    }
    if (/\.tf$/i.test(fp) || /\.tfvars$/i.test(fp)) {
      hasTerraform = true;
      infraFiles.push(fp);
    }
    if (/(?:^|\/)\.github\/workflows\//.test(fp) || base === ".gitlab-ci.yml" || base === "Jenkinsfile") {
      hasCI = true;
      infraFiles.push(fp);
    }
    if (base === "xtool.yml" || /(?:^|\/)k8s\//i.test(fp)) {
      infraFiles.push(fp);
    }
  }
  // detect k8s from paths
  for (const n of fileNodes) {
    if (/(?:^|\/)(k8s|kubernetes)\//i.test(n.filePath)) {
      hasK8s = true;
      if (!infraFiles.includes(n.filePath)) infraFiles.push(n.filePath);
    }
  }

  const deploymentTopology = {
    hasDockerfile,
    hasCompose,
    hasK8s,
    hasTerraform,
    hasCI,
    infraFiles: [...new Set(infraFiles)],
  };

  // Data pipeline
  const schemaFiles = [];
  const migrationFiles = [];
  const dataModelFiles = [];
  const apiHandlerFiles = [];
  for (const n of fileNodes) {
    const fp = n.filePath;
    const tags = n.tags || [];
    if (/\.(sql|graphql|gql|proto|prisma)$/i.test(fp) && !/migration/i.test(fp)) schemaFiles.push(fp);
    if (/migrations?\//i.test(fp) || /migration/i.test(fp)) migrationFiles.push(fp);
    if (/\/Models\//.test(fp) || tags.includes("model") || tags.includes("data-model")) dataModelFiles.push(fp);
    if (
      /\/(routes|controllers|handlers|api)\//i.test(fp) ||
      tags.includes("api-handler") ||
      tags.includes("endpoint")
    )
      apiHandlerFiles.push(fp);
  }
  const dataPipeline = { schemaFiles, migrationFiles, dataModelFiles, apiHandlerFiles };

  // Doc coverage
  const groupsWithDocsSet = new Set();
  const undocumentedGroups = [];
  for (const [g, ids] of Object.entries(directoryGroups)) {
    let hasDoc = false;
    for (const id of ids) {
      const n = idToNode.get(id);
      if (n.type === "document" || /\.(md|rst)$/i.test(n.filePath)) {
        hasDoc = true;
        break;
      }
      // README in group path
      if (/README\.md$/i.test(n.filePath)) {
        hasDoc = true;
        break;
      }
    }
    // also check if any document mentions the group via edges
    if (!hasDoc) {
      for (const e of allEdges) {
        if (e.type !== "documents") continue;
        const src = idToNode.get(e.source);
        const tgt = idToNode.get(e.target);
        if (src && tgt && idToGroup[e.target] === g && src.type === "document") {
          hasDoc = true;
          break;
        }
      }
    }
    if (hasDoc) groupsWithDocsSet.add(g);
    else undocumentedGroups.push(g);
  }
  const totalGroups = Object.keys(directoryGroups).length;
  const docCoverage = {
    groupsWithDocs: groupsWithDocsSet.size,
    totalGroups,
    coverageRatio: totalGroups === 0 ? 0 : groupsWithDocsSet.size / totalGroups,
    undocumentedGroups,
  };

  // Dependency direction
  const pairCounts = {};
  for (const { from, to, count } of interGroupImports) {
    const a = from < to ? from : to;
    const b = from < to ? to : from;
    const key = `${a}\0${b}`;
    if (!pairCounts[key]) pairCounts[key] = { [from]: 0, [to]: 0 };
    pairCounts[key][from] = (pairCounts[key][from] || 0) + count;
  }
  const dependencyDirection = [];
  for (const [, counts] of Object.entries(pairCounts)) {
    const groups = Object.keys(counts);
    if (groups.length < 2) continue;
    const [g1, g2] = groups;
    if (counts[g1] > counts[g2]) dependencyDirection.push({ dependent: g1, dependsOn: g2 });
    else if (counts[g2] > counts[g1]) dependencyDirection.push({ dependent: g2, dependsOn: g1 });
  }

  const filesPerGroup = {};
  for (const [g, ids] of Object.entries(directoryGroups)) filesPerGroup[g] = ids.length;
  const nodeTypeCounts = {};
  for (const [t, ids] of Object.entries(nodeTypeGroups)) nodeTypeCounts[t] = ids.length;

  const result = {
    scriptCompleted: true,
    directoryGroups,
    nodeTypeGroups,
    crossCategoryEdges,
    interGroupImports,
    intraGroupDensity,
    patternMatches,
    deploymentTopology,
    dataPipeline,
    docCoverage,
    dependencyDirection,
    fileStats: {
      totalFileNodes: fileNodes.length,
      filesPerGroup,
      nodeTypeCounts,
    },
    fileFanIn,
    fileFanOut,
  };

  try {
    fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
  } catch (e) {
    fail(`Failed to write output: ${e.message}`);
  }
  process.exit(0);
}

main();
