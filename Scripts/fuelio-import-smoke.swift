#!/usr/bin/env swift
import Foundation

func parseCSVRow(_ line: String) -> [String] {
    var fields: [String] = [], current = "", inQuotes = false
    var index = line.startIndex
    while index < line.endIndex {
        let ch = line[index]
        if inQuotes {
            if ch == "\"" {
                let next = line.index(after: index)
                if next < line.endIndex, line[next] == "\"" { current.append("\""); index = next }
                else { inQuotes = false }
            } else { current.append(ch) }
        } else if ch == "\"" { inQuotes = true }
        else if ch == "," { fields.append(current); current = "" }
        else { current.append(ch) }
        index = line.index(after: index)
    }
    fields.append(current)
    return fields
}

func section(_ text: String, name: String) -> [String] {
    let lines = text.split(whereSeparator: \.isNewline).map(String.init)
    let start = lines.firstIndex { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")).hasPrefix("## \(name)") }!
    var end = lines.count
    for i in (start+1)..<lines.count {
        if lines[i].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")).hasPrefix("## ") { end = i; break }
    }
    return Array(lines[(start+1)..<end]).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Scripts/Fuelio_2026-11-12.csv"
let text = try String(contentsOfFile: path, encoding: .utf8)
let vehicle = section(text, name: "Vehicle")
let log = section(text, name: "Log")
let vHeader = parseCSVRow(vehicle[0])
let vRow = Dictionary(uniqueKeysWithValues: zip(vHeader, parseCSVRow(vehicle[1])))
assert(vRow["Name"] == "Mazda3")
assert(vRow["FuelUnit"] == "0")
let header = parseCSVRow(log[0])
assert(header.contains("Date"))
assert(header.contains { $0.hasPrefix("Fuel") && !$0.hasPrefix("FuelType") })
var ok = 0
for line in log.dropFirst() {
    let row = Dictionary(uniqueKeysWithValues: zip(header, parseCSVRow(line)))
    if row["Date"] != nil, row["Odo (mi)"] != nil, row["Fuel (l)"] != nil { ok += 1 }
}
assert(ok == 48, "expected 48 fill-ups, got \(ok)")
print("fuelio-import-smoke: PASS (\(ok) fill-ups from \(path))")
