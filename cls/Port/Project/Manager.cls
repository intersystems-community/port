Include portutils

Class Port.Project.Manager
{

ClassMethod AssertUtilityCreation(type As %String, path As %String, logLevel As %String, sourceExtension As %String, Output sc As %Status) As Port.Project.Base [ Private ]
{
  set sc = $$$OK
  set utility = ""  
  set utilityTypes("E") = "Port.Project.Exporter"
  set utilityTypes("I") = "Port.Project.Importer"
  set utilityTypes("X") = "Port.Project.XMLExporter"
  try {
    set utility = $classmethod(utilityTypes(type), "%New", path, logLevel, sourceExtension)
    quit
  } catch ex {
    set sc = ex.AsStatus()
  }
  return utility
}

ClassMethod Export(outputPath As %String, logLevel As %Integer = 2, force As %Boolean = 0, ignoredPaths As %ListOfDataTypes = "", sourceExtension As %String = "") As %Status
{
  set exporter = ..AssertUtilityCreation("E", outputPath, logLevel, sourceExtension, .sc)
  $$$QuitOnError(sc)
  set exporter.Overwrite = force    
  $$$QuitOnError(exporter.Ignore(ignoredPaths))
  $$$QuitOnError(exporter.Export())
  set projectName = exporter.GetProjectName()
  if exporter.AffectedCount > 0 {
    $$$QuitOnError(##class(Port.SourceControl.Log).LogChange(projectName, projectName_".PRJ"))
  }
  return $$$OK
}

ClassMethod ExportToXML(outputPath As %String, logLevel As %Integer = 2, justProject As %Boolean = 0) As %Status
{
  set exporter = ..AssertUtilityCreation("X", outputPath, logLevel, "", .sc)
  $$$QuitOnError(sc)  
  return exporter.ExportToXML(justProject)
}

ClassMethod Import(inputPath As %String, logLevel As %Boolean = 2, skipBackup As %Boolean = 0, overwrite As %Boolean = 0, ignoredPaths As %ListOfDataTypes = "", sourceExtension As %String = "") As %Status
{
  set sc = $$$OK
  set importer = ..AssertUtilityCreation("I", inputPath, logLevel, sourceExtension, .sc)
  $$$QuitOnError(sc)
  $$$QuitOnError(importer.Ignore(ignoredPaths))
  
  set importer.SkipBackup = skipBackup
  set importer.IsBatch = 1
  set importer.Overwrite = overwrite   
  set projectName = importer.GetProjectName()
  
  $$$QuitOnError(importer.Import())
  
  if importer.AffectedCount > 0 {
    $$$QuitOnError(##class(Port.SourceControl.Log).LogChange(projectName, projectName_".PRJ"))
  }
  return sc
}

ClassMethod ImportPartial(basePath As %String, target, logLevel As %Boolean = 2, skipBackup As %Boolean = 0, overwrite As %Boolean = 0, ignoredPaths As %ListOfDataTypes = "", sourceExtension As %String = "") As %Status
{
  
  set importer = ..AssertUtilityCreation("I", basePath, logLevel, sourceExtension, .sc)  
  $$$QuitOnError(sc)
  $$$QuitOnError(importer.Ignore(ignoredPaths))
  
  set importer.LogLevel = logLevel
  set importer.SkipBackup = skipBackup
  set importer.Overwrite = 1
     
  $$$QuitOnError(importer.ImportPartial(target, .importedList))
  
  do ..LogFromImportList(importer.GetProjectName(), .importedList)
  return $$$OK
}

ClassMethod RemoveInvalidItems(projectName As %String = {^||Port.Project}) As %Status
{
  set project = ##class(%Studio.Project).%OpenId(projectName)
  $$$QuitOnError(project.Check())
  $$$QuitOnError(project.%Save()) 
  return $$$OK
}

ClassMethod RemoveItemsByType(projectName As %String, type As %String, Output items As %String) As %Status
{
  set sc = $$$OK
  set project = ##class(%Studio.Project).%OpenId(projectName)
  set s = ##class(%SQL.Statement).%New()
  $$$QuitOnError(s.%PrepareClassQuery("%Studio.Project", "ProjectItemsList"))
  set r = s.%Execute(projectName)
  
  while r.%Next() {
    set itemType = r.%Get("Type")
    set name = r.%Get("Name")
    if itemType = type {
      set items(name) = ""     
      set sc = project.RemoveItem(name, itemType)
      if $$$ISERR(sc) quit
    }
  }
  $$$QuitOnError(project.%Save())
  return sc
}

ClassMethod ExportTestSuiteToXML(outputPath As %String) As %Status
{
  set testPath = ##class(Port.Configuration).GetTestPath()
  set exporter = ..AssertUtilityCreation("X", .outputPath, 2, "", .sc)
  $$$QuitOnError(sc)
  return exporter.ExportTests(outputPath_"/"_testPath)
}

ClassMethod LogFromImportList(projectName As %String, ByRef importList As %String) [ Final, Internal, Private ]
{
  if 'importList quit
  
  for i=1:1:10 {
    do LoopThroughType(projectName, importList, i)
  }  
  
LoopThroughType(projectName, importedList, group)
  set itemName = "" 
  
  for {
    set itemName = $order(importList(group, $listget($$$ImportTypes, group), itemName))
    quit:itemName=""
    
    if group = 2 set itemName = itemName_".CLS"   
    do ##class(Port.SourceControl.Log).LogChange(projectName, itemName)
  }
  return 1
}

}

