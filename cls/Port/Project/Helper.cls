Class Port.Project.Helper [ Abstract ]
{

ClassMethod ImplyDirectoryCreation(path As %String) As %Status
{
  set isCreated = 1
  if '##class(%File).DirectoryExists(path)  {
    set isCreated = ##class(%File).CreateDirectoryChain(path)
    if isCreated = 0 {      
      quit $$$ERROR(5001, "Unable to create path: "_##class(%File).NormalizeFilename(path))
    }
  }
  quit $$$OK
}

ClassMethod IsRoutine(itemName As %String, onlyCompilables As %Boolean = 0) As %Boolean
{
  set extension = ..GetItemExtension(itemName)
  
  if extension = "MAC"  || (extension = "INT") ||
    (extension = "MVB") || (extension = "MVI") || 
    (extension = "BAS") {
    quit 1
  }
  
  if 'onlyCompilables {
    quit (extension = "INC" || (extension = "DFI"))
  }  
  quit 0
}

ClassMethod GetItemExtension(itemName As %String, upperCase As %Boolean = 1) As %String
{
  set ext = $piece(itemName, ".", $length(itemName, "."))
  quit $select(upperCase = 1 : $$$ucase(ext), 1: ext)
}

ClassMethod CSPToAbsoluteAppPath(cspItem As %String) As %String
{
  set installDirectory = $System.Util.InstallDirectory()
  set cspAppDirectory = $System.CSP.GetDefaultApp($namespace)
  set cspAppDirectory = $extract(cspAppDirectory, 2, *)
  quit ##class(%File).NormalizeFilename($replace(cspItem, cspAppDirectory, installDirectory_"csp/"_$$$lcase($namespace)))
}

ClassMethod FileToClass(path As %String) As %String
{
  set divider = $select($$$isWINDOWS : "\", 1: "/")
  set normalizedPath = ##class(%File).NormalizeFilename(path)
  quit $replace($extract(normalizedPath, $find(normalizedPath, divider_"cls")+1, $length(normalizedPath)-8), divider, ".")
}

ClassMethod ClassToFile(basePath As %String, className As %String, extension As %String = "txt")
{
  set divider = $select($$$isWINDOWS : "\", 1: "/")
  quit ##class(%File).NormalizeFilename(basePath_"/"_$replace(className, ".", divider)_".cls."_extension)
}

ClassMethod Normalize(name As %String, Output extension As %String, Output itemType As %String, Output itemName As %String)
{
   
  set nameOnly = $piece(name, ".", 1, $length(name, ".") - 1)  
  set routines = $listbuild("MAC", "INT", "INC", "MVB", "MVI", "BAS", "DFI")
  set extension = ..GetItemExtension(name)

  if ..IsRoutine(name) {
    set itemType = extension
    if extension = "INC" || (extension = "BAS") || (extension = "MVI") || (extension = "INT") {
      set itemType = "MAC"
    }
    set itemName = nameOnly_"."_extension  
  } elseif extension = "CLS" {
    set itemName = nameOnly  
    set itemType = extension
  } else {
    set itemName = name
    set itemType = "CSP"
  }
}

ClassMethod FileToCSPItem(source As %String, Output itemPath As %String, Output itemName As %String) As %Status
{
  set slash = $select($$$isWINDOWS : "\", 1: "/") 
  set installDir = $System.Util.InstallDirectory()
  set webFilePath = $extract(source, $find(source, slash_"web"_slash), *)
  set itemPath = ##class(%File).NormalizeFilename($System.Util.InstallDirectory()_"/csp/"_$namespace_"/"_webFilePath)
  set path = ##class(%File).GetDirectory(itemPath)
  set cspAppPath = $System.CSP.GetDefaultApp($namespace)
  set itemName = $extract(cspAppPath, 2, *)_"/"_$replace(webFilePath, "\", "/")
  quit $$$OK
}

}
