#!/usr/bin/env python3
"""Regenerates Resources/Templates/template.{doc,xlsx,pptx}: the smallest files Office opens cleanly.
Run once and commit the output; the build only copies the files."""
import pathlib
import subprocess
import tempfile
import zipfile

OUT = pathlib.Path(__file__).resolve().parent.parent / "Resources" / "Templates"
HEAD = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
PKG = "http://schemas.openxmlformats.org/package/2006/relationships"
REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
CT = "application/vnd.openxmlformats-officedocument."
NS = f'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="{REL}" ' \
     'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'


def rels(*targets):
    items = "".join(f'<Relationship Id="rId{i}" Type="{REL}/{kind}" Target="{target}"/>'
                    for i, (kind, target) in enumerate(targets, 1))
    return f'{HEAD}<Relationships xmlns="{PKG}">{items}</Relationships>'


def content_types(overrides):
    items = "".join(f'<Override PartName="{part}" ContentType="{CT}{kind}"/>' for part, kind in overrides)
    return (f'{HEAD}<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            f'<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            f'<Default Extension="xml" ContentType="application/xml"/>{items}</Types>')


def write_zip(path, parts):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, text in parts.items():
            z.writestr(name, text)


def xlsx():
    main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    write_zip(OUT / "template.xlsx", {
        "[Content_Types].xml": content_types([
            ("/xl/workbook.xml", "spreadsheetml.sheet.main+xml"),
            ("/xl/worksheets/sheet1.xml", "spreadsheetml.worksheet+xml"),
            ("/xl/styles.xml", "spreadsheetml.styles+xml")]),
        "_rels/.rels": rels(("officeDocument", "xl/workbook.xml")),
        "xl/workbook.xml": f'{HEAD}<workbook xmlns="{main}" xmlns:r="{REL}">'
                           '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>',
        "xl/_rels/workbook.xml.rels": rels(("worksheet", "worksheets/sheet1.xml"), ("styles", "styles.xml")),
        "xl/worksheets/sheet1.xml": f'{HEAD}<worksheet xmlns="{main}"><sheetData/></worksheet>',
        "xl/styles.xml": f'{HEAD}<styleSheet xmlns="{main}">'
                         '<fonts count="1"><font><sz val="12"/><name val="Calibri"/></font></fonts>'
                         '<fills count="2"><fill><patternFill patternType="none"/></fill>'
                         '<fill><patternFill patternType="gray125"/></fill></fills>'
                         '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
                         '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
                         '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>'
                         '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
                         '</styleSheet>',
    })


def pptx():
    tree = ('<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
            '<p:grpSpPr/></p:spTree></p:cSld>')
    colors = {"accent1": "4472C4", "accent2": "ED7D31", "accent3": "A5A5A5", "accent4": "FFC000",
              "accent5": "5B9BD5", "accent6": "70AD47", "hlink": "0563C1", "folHlink": "954F72"}
    solid = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
    theme = (f'{HEAD}<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">'
             '<a:themeElements><a:clrScheme name="Office">'
             '<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
             '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
             '<a:dk2><a:srgbClr val="44546A"/></a:dk2><a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>'
             + "".join(f'<a:{k}><a:srgbClr val="{v}"/></a:{k}>' for k, v in colors.items()) +
             '</a:clrScheme><a:fontScheme name="Office">'
             '<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
             '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>'
             '</a:fontScheme><a:fmtScheme name="Office">'
             f'<a:fillStyleLst>{solid * 3}</a:fillStyleLst>'
             f'<a:lnStyleLst>{f"<a:ln w=\"6350\">{solid}</a:ln>" * 3}</a:lnStyleLst>'
             f'<a:effectStyleLst>{"<a:effectStyle><a:effectLst/></a:effectStyle>" * 3}</a:effectStyleLst>'
             f'<a:bgFillStyleLst>{solid * 3}</a:bgFillStyleLst>'
             '</a:fmtScheme></a:themeElements></a:theme>')
    clr_map = ('<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" '
               'accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" '
               'folHlink="folHlink"/>')
    master_tree = tree.replace("<p:cSld>", '<p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>')
    write_zip(OUT / "template.pptx", {
        "[Content_Types].xml": content_types([
            ("/ppt/presentation.xml", "presentationml.presentation.main+xml"),
            ("/ppt/slideMasters/slideMaster1.xml", "presentationml.slideMaster+xml"),
            ("/ppt/slideLayouts/slideLayout1.xml", "presentationml.slideLayout+xml"),
            ("/ppt/slides/slide1.xml", "presentationml.slide+xml"),
            ("/ppt/theme/theme1.xml", "theme+xml")]),
        "_rels/.rels": rels(("officeDocument", "ppt/presentation.xml")),
        "ppt/presentation.xml": f'{HEAD}<p:presentation {NS}>'
                                '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
                                '<p:sldIdLst><p:sldId id="256" r:id="rId3"/></p:sldIdLst>'
                                '<p:sldSz cx="12192000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/>'
                                '</p:presentation>',
        "ppt/_rels/presentation.xml.rels": rels(("slideMaster", "slideMasters/slideMaster1.xml"),
                                                ("theme", "theme/theme1.xml"), ("slide", "slides/slide1.xml")),
        "ppt/slides/slide1.xml": f'{HEAD}<p:sld {NS}>{tree}<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>',
        "ppt/slides/_rels/slide1.xml.rels": rels(("slideLayout", "../slideLayouts/slideLayout1.xml")),
        "ppt/slideMasters/slideMaster1.xml": f'{HEAD}<p:sldMaster {NS}>{master_tree}{clr_map}'
                                             '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/>'
                                             '</p:sldLayoutIdLst></p:sldMaster>',
        "ppt/slideMasters/_rels/slideMaster1.xml.rels": rels(("slideLayout", "../slideLayouts/slideLayout1.xml"),
                                                             ("theme", "../theme/theme1.xml")),
        "ppt/slideLayouts/slideLayout1.xml": f'{HEAD}<p:sldLayout {NS} type="blank" preserve="1">'
                                             f'{tree.replace("<p:cSld>", "<p:cSld name=\"Blank\">")}'
                                             '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>',
        "ppt/slideLayouts/_rels/slideLayout1.xml.rels": rels(("slideMaster", "../slideMasters/slideMaster1.xml")),
        "ppt/theme/theme1.xml": theme,
    })


def doc():
    with tempfile.NamedTemporaryFile(suffix=".txt") as empty:
        subprocess.run(["textutil", "-convert", "doc", "-output", OUT / "template.doc", empty.name], check=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    xlsx()
    pptx()
    doc()
    print("Wrote", *sorted(p.name for p in OUT.iterdir()))
