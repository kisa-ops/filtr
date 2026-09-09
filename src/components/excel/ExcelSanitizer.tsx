import React, { useState, useRef } from 'react';
import { 
  Table, 
  FileSpreadsheet, 
  Download, 
  CheckCircle2, 
  Sparkles, 
  Sliders, 
  KeyRound, 
  Trash2,
  Layers,
  ArrowRight
} from 'lucide-react';
import * as XLSX from 'xlsx';
import type {  DetectionRule, ExcelSheetData, MaskingStrategy  } from '../../types';
import { ConsistencyVault } from '../../engine/consistencyMap';
import { scrubText } from '../../engine/rulesEngine';

interface ExcelSanitizerProps {
  rules: DetectionRule[];
  strategy: MaskingStrategy;
  onOpenVault: () => void;
}

export const ExcelSanitizer: React.FC<ExcelSanitizerProps> = ({
  rules,
  strategy,
  onOpenVault
}) => {
  const [sheetData, setSheetData] = useState<ExcelSheetData | null>(null);
  const [sheetNames, setSheetNames] = useState<string[]>([]);
  const [activeSheet, setActiveSheet] = useState<string>('');
  const [workbookRef, setWorkbookRef] = useState<XLSX.WorkBook | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (evt) => {
      const data = new Uint8Array(evt.target?.result as ArrayBuffer);
      const wb = XLSX.read(data, { type: 'array' });
      setWorkbookRef(wb);
      setSheetNames(wb.SheetNames);
      if (wb.SheetNames.length > 0) {
        loadSheet(wb, wb.SheetNames[0]);
      }
    };
    reader.readAsArrayBuffer(file);
  };

  const loadSheet = (wb: XLSX.WorkBook, sheetName: string) => {
    setActiveSheet(sheetName);
    const ws = wb.Sheets[sheetName];
    const jsonData = XLSX.utils.sheet_to_json<Record<string, any>>(ws, { header: 1 });

    if (!jsonData || jsonData.length === 0) {
      setSheetData(null);
      return;
    }

    const headers = (jsonData[0] as string[]) || [];
    const rows = jsonData.slice(1).map(rowArray => {
      const rowObj: Record<string, any> = {};
      headers.forEach((h, idx) => {
        rowObj[h] = (rowArray as any[])[idx] ?? '';
      });
      return rowObj;
    });

    const columnRules: Record<string, MaskingStrategy | 'none'> = {};
    headers.forEach(h => {
      columnRules[h] = strategy;
    });

    // Sanitize rows
    const vault = new ConsistencyVault();
    const sanitizedRows = rows.map(row => {
      const cleanRow: Record<string, any> = {};
      headers.forEach(h => {
        const val = String(row[h] || '');
        const colRule = columnRules[h];
        if (colRule === 'none') {
          cleanRow[h] = val;
        } else {
          const res = scrubText(val, rules, vault, { maskingStrategy: colRule || strategy });
          cleanRow[h] = res.sanitizedText;
        }
      });
      return cleanRow;
    });

    setSheetData({
      name: sheetName,
      headers,
      rows,
      sanitizedRows,
      columnRules
    });
  };


  const handleExportXLSX = () => {
    if (!sheetData) return;
    const ws = XLSX.utils.json_to_sheet(sheetData.sanitizedRows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, sheetData.name);
    XLSX.writeFile(wb, `sanitized_${sheetData.name}_${Date.now()}.xlsx`);
  };

  const handleExportCSV = () => {
    if (!sheetData) return;
    const ws = XLSX.utils.json_to_sheet(sheetData.sanitizedRows);
    const csv = XLSX.utils.sheet_to_csv(ws);
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sanitized_${sheetData.name}_${Date.now()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="flex-1 w-full h-full flex flex-col bg-slate-50 overflow-hidden">
      {/* Top Banner */}
      <div className="px-6 py-3 bg-white border-b border-slate-200 flex flex-wrap items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-bold text-slate-900 tracking-wide flex items-center gap-1.5">
              <Table className="w-4 h-4 text-emerald-400" />
              EXCEL & CSV TABULAR SANITIZER
            </h2>
            
          </div>
          <p className="text-xs text-slate-400 mt-0.5">
            Client-side .xlsx, .xls, and .csv grid scrubbing with column-level masking policies.
          </p>
        </div>

        <div className="flex items-center gap-2.5">
          <input
            type="file"
            ref={fileInputRef}
            onChange={handleFileUpload}
            accept=".xlsx,.xls,.csv,.tsv"
            className="hidden"
          />

          <button
            onClick={() => fileInputRef.current?.click()}
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold transition-colors shadow-md shadow-indigo-500/25"
          >
            <FileSpreadsheet className="w-3.5 h-3.5" />
            <span>Upload Spreadsheet</span>
          </button>

          {sheetData && (
            <>
              <button
                onClick={handleExportXLSX}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold transition-colors shadow-md shadow-emerald-500/25"
              >
                <Download className="w-3.5 h-3.5" />
                <span>Export .XLSX</span>
              </button>

              <button
                onClick={handleExportCSV}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-700 border border-slate-300 text-slate-700 text-xs font-semibold transition-colors"
              >
                <span>Export .CSV</span>
              </button>
            </>
          )}
        </div>
      </div>

      {/* Sheet Content Area */}
      {sheetData ? (
        <div className="flex-1 flex flex-col overflow-hidden">
          {/* Sheet Selector Tabs */}
          {sheetNames.length > 1 && (
            <div className="px-6 py-2 bg-slate-100 border-b border-slate-200 flex items-center gap-2">
              <span className="text-xs text-slate-500 font-medium">Sheets:</span>
              {sheetNames.map(name => (
                <button
                  key={name}
                  onClick={() => workbookRef && loadSheet(workbookRef, name)}
                  className={`px-3 py-1 rounded-lg text-xs font-medium transition-colors ${
                    activeSheet === name
                      ? 'bg-indigo-600 text-white font-semibold'
                      : 'bg-slate-100 text-slate-400 hover:text-white'
                  }`}
                >
                  {name}
                </button>
              ))}
            </div>
          )}

          {/* Split Table: Raw (Left) vs Sanitized (Right) */}
          <div className="flex-1 grid grid-cols-2 divide-x divide-slate-800 overflow-hidden">
            {/* Raw Grid */}
            <div className="flex flex-col overflow-hidden">
              <div className="px-4 py-2 bg-slate-50 border-b border-slate-200 text-xs font-bold text-slate-400 flex items-center justify-between">
                <span>ORIGINAL RAW SHEET ({sheetData.rows.length} rows)</span>
                <span className="text-[11px] text-slate-500">Unsanitized</span>
              </div>
              <div className="flex-1 overflow-auto font-mono text-xs">
                <table className="w-full text-left border-collapse">
                  <thead className="sticky top-0 bg-slate-100 z-10 border-b border-slate-200">
                    <tr>
                      {sheetData.headers.map(h => (
                        <th key={h} className="p-2.5 font-semibold text-slate-700 border-r border-slate-200">
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/60">
                    {sheetData.rows.map((row, idx) => (
                      <tr key={idx} className="hover:bg-slate-100/40">
                        {sheetData.headers.map(h => (
                          <td key={h} className="p-2.5 text-slate-400 border-r border-slate-200/60 whitespace-nowrap">
                            {row[h]}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Sanitized Grid */}
            <div className="flex flex-col overflow-hidden bg-slate-50/60">
              <div className="px-4 py-2 bg-slate-50 border-b border-slate-200 text-xs font-bold text-emerald-400 flex items-center justify-between">
                <span>SANITIZED MASKED SHEET</span>
                <span className="text-[11px] text-emerald-400/80 font-mono">100% In-Browser Scrubbed</span>
              </div>
              <div className="flex-1 overflow-auto font-mono text-xs">
                <table className="w-full text-left border-collapse">
                  <thead className="sticky top-0 bg-slate-100 z-10 border-b border-slate-200">
                    <tr>
                      {sheetData.headers.map(h => (
                        <th key={h} className="p-2.5 font-semibold text-indigo-300 border-r border-slate-200">
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/60">
                    {sheetData.sanitizedRows.map((row, idx) => (
                      <tr key={idx} className="hover:bg-indigo-950/20">
                        {sheetData.headers.map(h => {
                          const val = String(row[h] || '');
                          const isMasked = val.includes('[') && val.includes(']');
                          return (
                            <td key={h} className="p-2.5 border-r border-slate-200/60 whitespace-nowrap">
                              {isMasked ? (
                                <span className="px-1.5 py-0.5 rounded bg-indigo-950 text-indigo-300 border border-indigo-800/60 font-semibold text-[11px]">
                                  {val}
                                </span>
                              ) : (
                                <span className="text-slate-700">{val}</span>
                              )}
                            </td>
                          );
                        })}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      ) : (
        <div className="flex-1 flex flex-col items-center justify-center text-slate-500">
          <Table className="w-12 h-12 text-slate-600 mb-3" />
          <p className="font-sans font-medium text-slate-700 text-base">No Spreadsheet Loaded</p>
          <p className="font-sans text-xs text-slate-500 mt-1 max-w-sm text-center">
            Upload an Excel (.xlsx) or CSV file with employee, customer, or system data to preview and scrub columns.
          </p>
          <div className="flex items-center gap-3 mt-4">
            <button
              onClick={() => fileInputRef.current?.click()}
              className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold transition-colors shadow-lg shadow-indigo-500/20"
            >
              Upload Local File
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
