Include portutils

Class UnitTest.Port.Helper [ Abstract ]
{

Parameter MOCKAPPNAME = "/unittest/mockapp";

ClassMethod CreateMockApplication() As %Status
{
  set ns = $namespace
  new $namespace
  
  set $namespace = "%SYS"
  set properties("Path") = ##class(%File).NormalizeFilename($System.Util.InstallDirectory()_"csp/mockapp")
  set properties("NameSpace") = ns
  set properties("IsNameSpaceDefault") = 1
  
  if ##class(Security.Applications).Exists(..#MOCKAPPNAME) {
    $$$QuitOnError(..DestroyMockApplication())
  }
  return ##class(Security.Applications).Create(..#MOCKAPPNAME, .properties)
}

ClassMethod DestroyMockApplication() As %Status
{
  
  set ns = $namespace
  new $namespace
  
  set $namespace = "%SYS"
  do ##class(%File).RemoveDirectoryTree($System.Util.InstallDirectory()_"csp/mockapp")
  return ##class(Security.Applications).Delete(..#MOCKAPPNAME)
}

ClassMethod MockItems(projectName As %String, Output items As %List = "", Output outputs As %List = "")
{
  #define CurrentWorkspace(%item) $$$NFN($$$FormatText("%1/%2", ##class(Port.Configuration).GetWorkspace(projectName), %item))
  
  set currentApp = $extract($System.CSP.GetDefaultApp($namespace), 2, *)
  set a = $lb("PKG", "CLS", "CLS", "PKG", "PKG", "INC", "MAC", "DFI", "BAS", "MVB", "MVI", "CSP", "HTML", "HTML", "JS", "HTML", "ONLYEXTENSION", "PRJ")
  
  set items = $lb(
    "Dummy.PKG",
    "Dummy.Class.CLS",
    "Dummy.Another.Package.Here.CLS",
    "Dummy.And.Here.We.Shall.Test.Packages.PKG",
    "Dummy.And.Here.We.Shall.Test.Packages.Without.Extension.PKG",
    "dummy.INC",
    "dummy.MAC",
    "dummy.DFI",
    "dummy.BAS",
    "dummy.MVB",
    "dummy.MVI",
    $$$FormatText("%1/dummy/index.csp", currentApp), 
    $$$FormatText("%1/dummy/index.html", currentApp),
    $$$FormatText("%1/dummy/composite.name.should.still.resolve.html", currentApp),
    $$$FormatText("%1/dummy/js/some/deep/file.js", currentApp),
    $$$FormatText("%1/dummy/js/some/deep/file.html", currentApp),
    $$$FormatText("%1/dummy/js/some/deep/.onlyextension", currentApp)
  )
  
  set outputs = $lb(
    $$$CurrentWorkspace("cls/Dummy"),
    $$$CurrentWorkspace("cls/Dummy/Class.cls"),
    $$$CurrentWorkspace("cls/Dummy/Another/Package/Here.cls"),
    $$$CurrentWorkspace("cls/Dummy/And/Here/We/Shall/Test/Packages"),
    $$$CurrentWorkspace("cls/Dummy/And/Here/We/Shall/Test/Packages/Without/Extension"),
    $$$CurrentWorkspace("inc/dummy.inc"),
    $$$CurrentWorkspace("mac/dummy.mac"),
    $$$CurrentWorkspace("dfi/dummy.dfi"),
    $$$CurrentWorkspace("bas/dummy.bas"),
    $$$CurrentWorkspace("mvb/dummy.mvb"),
    $$$CurrentWorkspace("mvi/dummy.mvi"),
    $$$CurrentWorkspace("web/dummy/index.csp"),
    $$$CurrentWorkspace("web/dummy/index.html"),
    $$$CurrentWorkspace("web/dummy/composite.name.should.still.resolve.html"),
    $$$CurrentWorkspace("web/dummy/js/some/deep/file.js"),
    $$$CurrentWorkspace("web/dummy/js/some/deep/file.html"),
    $$$CurrentWorkspace("web/dummy/js/some/deep/.onlyextension")    
  )
}

ClassMethod CreateDummyProject()
{
  set dummy = ##class(%Studio.Project).%New()
  set dummy.Name = "dummy-project"
  do dummy.AddItem("Port.SourceControl.AutoInstall.CLS")
  set sc = dummy.%Save()
  quit sc
}

ClassMethod RemoveDummyProjectItem()
{
  set dummy = ##class(%Studio.Project).%OpenId("dummy-project")
  do dummy.RemoveItem("Port.SourceControl.AutoInstall.CLS")
  quit dummy.%Save()
}

ClassMethod CloneTestProject(fixturePath As %String, projectName As %String, usingXMLOnly As %Boolean = 0) As %Status
{
   
  set source = $$$NFN($$$FormatText("%1/%2", fixturePath, projectName))
  set dest = $$$NFN($$$FormatText("%1/_/%2", fixturePath, projectName))
  if 'usingXMLOnly {
    set copied = ##class(%File).CopyDir(source, dest, 1,, 1)
    if 'copied return $$$PERROR($$$UnableToCopySource, source, dest)
  } else {
    set originXML = $$$NFN($$$FormatText("%1/%2.xml", source, projectName))
    set destinationXML = $$$NFN($$$FormatText("%1/%2.xml", dest, projectName))
    do ##class(%File).CreateDirectoryChain(##class(%File).GetDirectory(destinationXML))
    set copied = ##class(%File).CopyFile(originXML, destinationXML, 1)
    if 'copied return $$$PERROR($$$UnableToCopySource, source, dest)
  }
    
  $$$QuitOnError(##class(%Studio.Project).Import($$$FormatText("%1/%2.xml", dest, projectName), "/nodisplay"))
  // We don't want to overwrite the original dummy-project, but the clone instead.
  do ##class(Port.Configuration).SetCustomWorkspace(projectName, dest)
  
  return $$$OK
}

ClassMethod DeleteTestProject(fixturePath As %String, projectName As %String = "dummy-project") As %Status
{
  set rows = ##class(%SQL.Statement).%ExecDirect(, "SELECT NAME FROM %STUDIO.PROJECTITEM WHERE PROJECT = ?", projectName)
  while rows.%Next(.sc) {
    if $$$ISERR(sc) return sc
    set itemName = rows.%Get("Name")
    set isClass = ##class(%Dictionary.ClassDefinition).%ExistsId(itemName)
    
    if (##class(Port.Util).IsRoutine(itemName) || 
        ##class(%RoutineMgr).IsCSPName(itemName) ||
        isClass
    ) {
      // We use %SYSTEM.OBJ.Delete here because it supports qualifiers and we don't want to pollute the test feedback.
      if isClass set sc = $System.OBJ.Delete(itemName, "/nodisplay")
      else  set sc = ##class(%RoutineMgr).Delete(itemName)
      if $$$ISERR(sc) return sc
    } else {
      set sc = ##class(Port.Util).CSPPhysicalToLogicalPath(itemName, .logicalPath)
      if $$$ISERR(sc) return sc
      set sc = ##class(%File).Delete(logicalPath)
      if $$$ISERR(sc) return sc
    }
  }
  set normalizedTargetDir = $$$NFN($$$FormatText("%1/_", fixturePath))
  
  set removed = ##class(%File).RemoveDirectoryTree(normalizedTargetDir)
  if 'removed return $$$PERROR($$$UnableToRemoveDirectory, normalizedTargetDir)
  
  do ##class(Port.Configuration).RemoveCustomWorkspace(projectName)
  return $System.OBJ.DeleteProject(projectName)
}

ClassMethod GetTestProjectItemsPath(projectName As %String, fixturePath As %String) As %ArrayOfDataTypes
{
  set locations = ##class(%ArrayOfDataTypes).%New()
  set rows = ##class(%SQL.Statement).%ExecDirect(, "SELECT NAME, TYPE FROM %STUDIO.PROJECTITEM WHERE PROJECT = ?", projectName)
  while rows.%Next(.sc) {
    if $$$ISERR(sc) return sc
    set type = rows.%Get("Type")
    set itemName = rows.%Get("Name")
    
    if type = "CLS" set itemName = itemName_".CLS"
    set location = ##class(Port.Util).MountItemSourcePath(itemName, fixturePath)
    
    do locations.SetAt(location, itemName)
  }
  quit locations
}

}

