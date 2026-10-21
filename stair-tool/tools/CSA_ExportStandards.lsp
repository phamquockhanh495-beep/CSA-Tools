;;; CSA_ExportStandards.lsp - read-only DWG standards inventory.
;;; Load with APPLOAD, then run CSA_EXPORT_STANDARDS.
;;; No commands, entities, system variables or table definitions are changed.

(defun csaexp:str (v)
  (cond ((null v) "") ((= (type v) 'STR) v) (T (vl-princ-to-string v))))

(defun csaexp:csv (v / s i ch out)
  (setq s (csaexp:str v) i 1 out "\"")
  (repeat (strlen s)
    (setq ch (substr s i 1)
          out (strcat out (if (= ch "\"") "\"\"" ch))
          i (1+ i)))
  (strcat out "\""))

(defun csaexp:row (f values / line sep v)
  (setq line "" sep "")
  (foreach v values
    (setq line (strcat line sep (csaexp:csv v)) sep ","))
  (write-line line f))

(defun csaexp:fail (message)
  (princ (strcat "\n" message))
  (exit))

(defun csaexp:d (code data) (cdr (assoc code data)))

(defun csaexp:handle (v / data)
  (if (= (type v) 'ENAME)
    (progn
      (setq data (entget v))
      (strcat "HANDLE=" (csaexp:str (csaexp:d 5 data))
              ";NAME=" (csaexp:str (csaexp:d 2 data))))
    (csaexp:str v)))

(defun csaexp:open (path)
  ;; Unicode engines support UTF-8 BOM (AutoCAD 2021+).
  (if (and (getvar "LISPSYS") (> (getvar "LISPSYS") 0))
    (open path "w" "utf8-bom")
    (open path "w")))

(defun csaexp:layers (f / d color flags)
  (csaexp:row f '("Name" "ACI_signed" "TrueColor_420" "ColorName_430"
    "Linetype" "Lineweight_370" "Flags_70" "On" "Frozen" "Locked"
    "Plot_290" "Transparency_440" "PlotStyle_390" "Description_4"))
  (setq d (tblnext "LAYER" T))
  (while d
    (setq d (entget (tblobjname "LAYER" (csaexp:d 2 d)))
          color (csaexp:d 62 d) flags (csaexp:d 70 d))
    (csaexp:row f
      (list (csaexp:d 2 d) color (csaexp:d 420 d) (csaexp:d 430 d)
        (csaexp:d 6 d) (csaexp:d 370 d) flags
        (if (and color (< color 0)) "No" "Yes")
        (if (/= 0 (logand 1 flags)) "Yes" "No")
        (if (/= 0 (logand 4 flags)) "Yes" "No")
        (csaexp:d 290 d) (csaexp:d 440 d)
        (csaexp:handle (csaexp:d 390 d)) (csaexp:d 4 d)))
    (setq d (tblnext "LAYER"))))

(defun csaexp:styles (f / d)
  (csaexp:row f '("Name" "Font" "BigFont" "FixedHeight" "WidthFactor"
    "ObliqueAngle_radians" "Flags" "GenerationFlags"))
  (setq d (tblnext "STYLE" T))
  (while d
    (csaexp:row f (list (csaexp:d 2 d) (csaexp:d 3 d) (csaexp:d 4 d)
      (csaexp:d 40 d) (csaexp:d 41 d) (csaexp:d 50 d)
      (csaexp:d 70 d) (csaexp:d 71 d)))
    (setq d (tblnext "STYLE"))))

(defun csaexp:blocks (f af / d name e ed kind count attrs flags)
  (csaexp:row f '("Name" "Handle" "BasePoint" "Flags" "Anonymous"
    "Xref" "XrefPath" "EntityCount" "AttributeDefinitionCount"))
  (csaexp:row af '("Block" "Tag" "Prompt" "DefaultText" "Flags"
    "Constant" "Invisible" "Layer" "TextStyle" "Height" "InsertPoint"))
  (setq d (tblnext "BLOCK" T))
  (while d
    (setq name (csaexp:d 2 d) flags (csaexp:d 70 d)
          count 0 attrs 0 e (csaexp:d -2 d))
    ;; -2 is the first entity of this definition. Stop at ENDBLK.
    (while e
      (setq ed (entget e) kind (csaexp:d 0 ed))
      (if (= kind "ENDBLK")
        (setq e nil)
        (progn
          (setq count (1+ count))
          (if (= kind "ATTDEF")
            (progn
              (setq attrs (1+ attrs))
              (csaexp:row af (list name (csaexp:d 2 ed) (csaexp:d 3 ed)
                (csaexp:d 1 ed) (csaexp:d 70 ed)
                (if (/= 0 (logand 2 (csaexp:d 70 ed))) "Yes" "No")
                (if (/= 0 (logand 1 (csaexp:d 70 ed))) "Yes" "No")
                (csaexp:d 8 ed) (csaexp:d 7 ed) (csaexp:d 40 ed)
                (csaexp:d 10 ed)))))
          (setq e (entnext e)))))
    (csaexp:row f (list name (csaexp:handle (tblobjname "BLOCK" name))
      (csaexp:d 10 d) flags
      (if (/= 0 (logand 1 flags)) "Yes" "No")
      (if (/= 0 (logand 12 flags)) "Yes" "No")
      (csaexp:d 1 d) count attrs))
    (setq d (tblnext "BLOCK"))))

(defun csaexp:raw (f / table d name pair full)
  ;; Preserve exact DXF records, including dimension styles and linetype
  ;; segment patterns. Repeated codes retain their original order.
  (csaexp:row f '("Table" "Name" "DXF_Code" "Value"))
  (foreach table '("LAYER" "LTYPE" "STYLE" "DIMSTYLE" "BLOCK")
    (setq d (tblnext table T))
    (while d
      (setq name (csaexp:d 2 d)
            full (entget (tblobjname table name) '("*")))
      (foreach pair full
        (csaexp:row f (list table name (car pair) (csaexp:handle (cdr pair)))))
      (setq d (tblnext table)))))

(defun c:CSA_EXPORT_STANDARDS (/ *error* target stem suffix path paths f af
                               generated overwrite proceed variable)
  (defun *error* (message)
    (if f (close f))
    (if af (close af))
    (if (and message (not (member message '("Function cancelled" "quit / exit abort"))))
      (princ (strcat "\nExport stopped: " message)))
    (princ "\nDWG unchanged. Any partial output files may be deleted and regenerated.")
    (princ))
  (setq target (getfiled "CSA: choose report location (not the DWG)"
    (strcat (getvar "DWGPREFIX") "CSA_Standards.csv") "csv" 1))
  (if target
    (progn
      (setq stem (strcat (vl-filename-directory target) "\\" (vl-filename-base target))
            paths nil overwrite nil proceed T)
      (foreach suffix '("_layers.csv" "_blocks.csv" "_attributes.csv"
                        "_textstyles.csv" "_tables_dxf.csv" "_drawing.csv")
        (setq path (strcat stem suffix) paths (cons path paths))
        (if (findfile path) (setq overwrite T)))
      (if overwrite
        (progn
          (initget "Yes No")
          (setq proceed (= "Yes" (getkword "\nReports exist. Overwrite? [Yes/No] <No>: ")))))
      (if proceed
        (progn
          (setq f (csaexp:open (strcat stem "_layers.csv")))
          (if (not f) (csaexp:fail "Cannot create layer report."))
          (csaexp:layers f) (close f) (setq f nil)
          (setq f (csaexp:open (strcat stem "_blocks.csv"))
                af (csaexp:open (strcat stem "_attributes.csv")))
          (if (or (not f) (not af)) (csaexp:fail "Cannot create block reports."))
          (csaexp:blocks f af) (close f) (close af) (setq f nil af nil)
          (setq f (csaexp:open (strcat stem "_textstyles.csv")))
          (if (not f) (csaexp:fail "Cannot create text style report."))
          (csaexp:styles f) (close f) (setq f nil)
          (setq f (csaexp:open (strcat stem "_tables_dxf.csv")))
          (if (not f) (csaexp:fail "Cannot create DXF table report."))
          (csaexp:raw f) (close f) (setq f nil)
          (setq f (csaexp:open (strcat stem "_drawing.csv")))
          (if (not f) (csaexp:fail "Cannot create drawing report."))
          (csaexp:row f '("Property" "Value"))
          (csaexp:row f (list "DWGNAME" (getvar "DWGNAME")))
          (csaexp:row f (list "ExportedAt_CDATE" (getvar "CDATE")))
          (foreach variable '("ACADVER" "INSUNITS" "MEASUREMENT" "LUNITS"
                             "LUPREC" "DIMSCALE" "DIMSTYLE" "TEXTSTYLE" "LTSCALE")
            (csaexp:row f (list variable (getvar variable))))
          (close f) (setq f nil)
          (princ "\nCSA export complete. DWG unchanged. Send all 6 CSV files:")
          (foreach path (reverse paths) (princ (strcat "\n" path)))))))
  (princ))

(vl-load-com)
(princ "\nCSA standards exporter loaded. Run CSA_EXPORT_STANDARDS.")
(princ)
