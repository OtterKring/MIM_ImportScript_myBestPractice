# Best practice recommendation for writing an Import Script for Microsoft Identity Manager with PSMA

*work in progress*




## PSM... what?

[PSMA is a Management Agent for Microsoft Identity Manager](https://github.com/sorengranfeldt/psma) (MIM, former FIM: "Forefront Identity Manager") created by [Søren Granfeldt](https://github.com/sorengranfeldt) which allows using Powershell scripts to build the bridge between MIM and the systems you want to exchange data with.

There are plenty of Management Agents available for MIM written for specific systems like SAP, Exchange, ActiveDirectory (included in MIM) and many more. PSMA's advantage, and by MIM die-hards often loathed feature, is that you can completely control how the data is transferred between MIM and your system of interest, while not being restricted to a specific API and not having to learn C# or another high level programming language. The only thing necessary is any kind of interface Powershell can use to communicate with your system: an API, a REST web hook, a specific Powershell module, etc.

**If you are interested in my personal approach to the topic, you can read my story [here](./MIM_Personal.md).**


# Parts of a PSMA import script

A PSMA import script consists of **5 main parts**:

* control data handed to the script by parameters
* global variables
* the data retrieval from the "external" system
* the mail loop building the output data structure for MIM

Søren Granfeldt gives a clear but in my opinion very rough [overview](https://github.com/sorengranfeldt/psma/wiki/Import) over these parts. Together with Darren Robinson's [instructions](https://blog.darrenjrobinson.com/using-the-new-granfeldt-fim-mim-powershell-management-features/) you can make sense of it, but in my opinion it is still quite a challenge.

So let me try to break it up ...

## 1) The Schema

The Schema is a .ps1 file of its own holding a PSCustomObject which describes the data set you will return to MIM. Every fields you want to import in MIM must be defined there.

The definition is pretty straight forward so I leave you to [Søren Granfeldt's original explanation.](https://github.com/sorengranfeldt/psma/wiki/Schema).

Why he is using the slow `Add-Member` to build the object and then explicitly returns it, I don't know. I am pretty sure, you could build the PSCustomObject like this, too, taking his example as a reference:

```
[PSCustomObject]@{
    'Anchor-Id|String'      = 1
    'objectClass|String'    = 'user'
    'AccountName|String'    = 'SG'

    <# etc., you get the idea >

}
```

However, I haven't tested this, yet, and since it has no relevant influence on usability or performance of your PSMA Management Agent, it will imho remain a matter of taste.

**NOTE:**

The "Anchor-" prefix for the field being used as Anchor in MIM as well as the different "|type" postfixes are only used in the Schema script! In the import script it would still remain 'Id', 'objectClass','AccountName', ...!

## 2) Parameters
*I am only covering the basic parameters here (the ones I used and therefor had to understand 😉). Please consult Mr Granfledt's instructions for additional ones*

Parameter|Description
---|---
`$Username` and `$Password`|as they were entered for the Management Agent in MIM. These should be the credentials used to access your external system. **NOTE: the password is sent in clear text!** So I advise against using this parameter pair, if your system can handle SecureString passwords. (VSCode will complain about the use of a plain text $Password parameter, too.)
`$Credentials`|same as above, but already as `[PSCredential]` object, so the password is a SecureString already and you don't have to convert it anymore. 
`$OperationType`|tells your script, if it should do a *FULL* import or a *DELTA* import. It does not do this by itself of course. You have to check for `$OperationType -eq 'FULL'` (not case sensitive) or `$OperationType -eq 'DELTA'`. In fact you only have to check for one of the two, because if it is not the one, it must be the other and can be taken care of in the `else` clause of your conditional.
  
This is enough for basic importing to do everything in one run. If you have a lot of data to import, it is recommended to use *paged importing*, which breaks the amount of data in pre-defined chunks, so you don't have to wait for the whole import to finish when e.g. interrupting an import.
It might also be a matter of memory. You don't want to run out of memory because your script is hogging all the data before sending it to MIM.

Parameter|Description
---|---
`$UsePagedImport`|is the `boolean` flag which MIM sets to `$true` if a paged import is requested.
`$PageSize`|holds the integer number of datasets to process in one run. The script is called multiple times until all the data has been imported. To keep control over where you are in the process you must make use of the `$global` control variables PSMA offers. More about that shortly.

Finally, though I have not used or wrapped my head around it, yet, I want to mention the `$Schema` parameter, which holds the schema data you have defined in the schema.ps1. It offers the possibility to dynamically react to schema changes in your script. For more information about this, please consult Mr Grandfeldt's instructions.


## 3) Global Variables / Control data

PSMA offers a couple of global variables to control your data flow. The first one, `$global:RunStepCustomData` is the only one generally neede for each type of import, if delta import should be supported, the others are only necessary for *paged import*:

Variable|Description
---|---
`$global:RunStepCustomData`|can hold any data suiting you to save a time stamp for a delta import. The data is saved within MIM/PSMA and can be retrieved on the next run to import only the datasets changed since the latest import.
`$global:tenantObjects`|holds all the objects you want to import. You usually pull all your data from the source system into this variable and then import it page by page.
`$global:objectsImported`|an integer counter which keeps track of the number of tenantObjects you have processed already.
`$global:PageToken`|an integer counter to keep track how many tenantObjects you have processed since the current page started. The `$PageSize` parameter must be checked in the import loop for the limit.
`$global:MoreToImport`|a boolean flag which tells PSMA to recall the script for another import page if `$true` or to tell MIM that we are done importing (`$false`).


## 4) Data retrieval

This part is totally up to you. You know your external system best, so use which ever code suits you best to get the data you need into the script.

## 5) The data processing loop

This is were the music plays. Whatever you want to do with your data, it must happen in this loop while processing each and every dataset coming from your input source.

Now, in an ideal world or in the world of a real MIM-Expert, all the import script has to do is take the original data one by one and map it to the fields defined in your Schema.ps1. Even if you need your data to be transformed in any way, it could probably be done using MIM's internal functions, workflows, etc.

However, both is very unlikely if you have not spent a lot of hours learning MIM internals.


In most references about importing scripts I found a copy Mr Grandfeldt's technique to build the output hashtable for MIM:

```
# define a hashtable
$obj = @{}

# start the processing loop
foreach ($dataset in $InputData) {

    # add hashtable fields one by one
    $obj.Add('Id',$dataset.Id)
    $obj.Add('AccountName,$dataset.LastName)
    $obj.Add('DoB',$dataset.WhenBorn)
    ...

    # return the hashtable to MIM
    $obj

}
```

From a first glance there is nothing bad. Straight forward, going with the flow, adding the fields as it suits you, then returning the data to MIM.

As I said before, in an ideal world, this actually is all you have to do.

But then you find, your company has different formats for costcenters in different countries, and since you are not familiar with MIM's internal possibilities or know, you have others in your team knowing Powershell but nobody knowing MIM, you add to the code:

```
    $CC = $switch ($dataset.Country) {
        'US' { $dataset.CostCenter + '-HQ'; break }
        'MX' { $dataset.CostCenter -replace '^\d\d\','MX'; break }
        'DE' { [regex]::Match($dataset.CostCenter,'\d{4}(?=\-)').Value; break }
        Default { $dataset.CostCenter }
    }
    $obj.Add('CostCenter',$CC)
```

Oh, and the office in UK needs the building number in front of the street, well, ok:

```
    if ($dataset.Country -ne 'UK') {
        $StreetAddress = $dataset.Street + ' ' + $dataset.BuildingNr
    } else {
        $StreetAddress = $dataset.BuildingNr + ' ' $dataset.Street
    }
    $obj.Add('StreetAddress',$StreetAddress)
```

... and so on. Soon you will have code all over the place where you had your fields listed and have a really hard time finding anything anymore.


**Therefor I strongly propose a different approach:**

In opposition to other automation scripts you may have written, an import script for MIM is not about the code or algorithm but solely about the data!

Let this sink in.

Instead of writing your code in a sequence of processes concentrate on the data you are working with:
1) the data coming into your script
2) the data going out of your script

... and nothing else matters!

Instead of adding each field individually to your output hashtable, create one hashtable at once and _use a function to fill each field_, even if the function just returns a variable unaltered. Just for consistency.

Putting together the examples from above this would look like this:

```
#-FUNCTIONS-------------------

function Get-OutputId {
    $dataset.Id
}

function Get-OutputAccountName {
    $dataset.AccountName
}

function Get-OutputDoB {
    $dataset.WhenBorn
}

function Get-OutputCostCenter {
    $switch ($dataset.Country) {
        'US' { $dataset.CostCenter + '-HQ'; break }
        'MX' { $dataset.CostCenter -replace '^\d\d\','MX'; break }
        'DE' { [regex]::Match($dataset.CostCenter,'\d{4}(?=\-)').Value; break }
        Default { $dataset.CostCenter }
    }
}

function Get-OutputStreetAddress {
    if ($dataset.Country -ne 'UK') {
        $StreetAddress = $dataset.Street + ' ' + $dataset.BuildingNr
    } else {
        $StreetAddress = $dataset.BuildingNr + ' ' $dataset.Street
    }
}


#-Data-Input----------------------
    <# totally on you #>

#-Processing-Loop-----------------

# no need to define a hashtable in advance

# start the processing loop
foreach ($dataset in $InputData) {

    $Output = @{
        Id              = Get-OutputId
        AccountName     = Get-OutputAccountName
        DoB             = Get-OutputDoB
        CostCenter      = Get-OutputCostCenter
        StreetAddress   = Get-OutputStreetAddress
        ...
    }

    $Output

}
```

You see? All nicely divided, code and data, each easy to find and to maintain. No questions open. You could even define the hashtable without assigning it to a variable, so it gets returned directly. Assigning it to a variable just gives you the freedom to still do something with it later in the code. (Logging!)


With all that in mind, let's create our ...

## Basic Importing Template

```
param(
    [PSCredential]$Credentials,
    [string]$OperationType
)

#-Functions-----------------------------------------

function Get-OutputId {

}

function Get-OutputAccountName {

}

function Get-OutputWhenBorn {

}

...

#-General-Preparations------------------------------

    # import modules
    # define variables
    # whatever ..


#-Importing-Data------------------------------------

# save current time right before importing from the source

$Now = [datetime]::Now

# Get the data from your input source. Replace the pseudo code Get-MySourceData with your actual API call.
# Do a DELTA import if requested AND a timestamp from a previous import exists, otherwise run a FULL import

$InputData = if ($OperationType -eq "DELTA" -and $global:RunStepCustomData) {
    Get-MySourceData -ChangedAfter $global:RunStepCustomData
} else {
    Get-MySourceData
}

# Save timestamp for delta import. I only save a new timestamp, if we received new data, just to make sure we don't miss anything the next time. Not getting data might have been unintended behavior.
# the "-as [array]" conversion ensures we get a count of 1 if the import contains only one dataset and did not create an array but just a single object

if (($InputData -as [array]).count -gt 0) {
    $global:RunStepCustomData = $Now
}


#-Processing-Loop-----------------------------------

foreach ($dataset in $InputData) {

    $Output = @{
        Id          = $dataset.Id
        AccountName = $dataset.LastName
        DoB         = $dataset.WhenBorn
        ...
    }

    $Output

}
```


## Paged Importing



