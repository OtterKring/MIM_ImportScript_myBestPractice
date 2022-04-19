<#
.SYNOPSIS
Search for attribute including a specific string in a Workday Worker XML

.DESCRIPTION
Search for attribute including a specific string in a Workday Worker XML

.PARAMETER Xml
The XML data as returned e.g. by Get-WorkdayWorkerAdv

.PARAMETER SearchString
The string to search for in the attributes' name.

.EXAMPLE
Get-WorkdayWorkerAdv -WorkerId 1000123 | Find-XMLAttribute -SearchString 'hire'

Returns all fields containing the string "hire" and there values

.NOTES
2022-04-15 ... initial version by Maximilian Otter
#>
function Find-XMLAttribute {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [System.Xml.XmlDocument]
        $Xml,
        [string]
        $SearchString
    )

    begin {

        # function to recurse through all xml nodes and return the individual data fields and their paths withing the xml
        function Expand-ChildNodes ($Nodes,[string]$Path = 'Xml') {

            # when in recursation $Nodes will contain a collection, most of the times with only 1 member, but it could be more
            foreach ($node in $Nodes) {

                # Get the relevant properties of the node (not the xml internal stuff which select * would return)
                $Properties = Get-Member -InputObject $node -MemberType Property

                foreach ($property in $Properties) {
                    $ChildPath = "$Path.$($property.Name)"

                    # properties with "System.Xml.XmlElement" in the definition contain more nodes -> recurse
                    # node names do not need to be unique, so there Where{} returns a collection, even if it just one item
                    if ($property.Definition -like 'System.Xml.XmlElement*') {
                        Expand-ChildNodes -Nodes $node.ChildNodes.Where{$_.LocalName -eq $property.Name} -Path $ChildPath
                    } else {
                        # again: collection returned, foreach necessary. unlikely, but may result in duplicate fields in output
                        foreach ($childnode in ($node.ChildNodes.Where{$_.LocalName -eq $property.Name})) {
                            [PSCustomObject]@{
                                Path = $ChildPath
                                Name = $property.Name
                                Value = $childnode.'#text'
                            }
                        }
                    }
                }
            }

        }


    }

    process {

        Expand-ChildNodes -Nodes $Xml | Where-Object Name -like "*$SearchString*"

    }
}