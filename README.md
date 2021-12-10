# Best practice recommendation for writing an Import Script for Microsoft Identity Manager with PSMA
last update: Dec 2021

## PSM... what?

[PSMA is a Management Agent for Microsoft Identity Manager](https://github.com/sorengranfeldt/psma) (MIM, former FIM: "Forefront Identity Manager") created by [Søren Granfeldt](https://github.com/sorengranfeldt) which allows using Powershell scripts to build the bridge between MIM and the systems you want to exchange data with.

There are plenty of Management Agents available for MIM written for specific systems like SAP, Exchange, ActiveDirectory (included in MIM) and many more. PSMA's advantage, and by MIM die-hards an often loathed feature, is, that you can completely control how the data is transferred between MIM and your system of interest, while not being restricted to a specific API and not having to learn C# or another high level programming language. The only thing necessary is any kind of interface Powershell can use to communicate with your system: an API, a REST web hook, a specific Powershell module, etc.

**If you are interested in my personal approach to the topic, you can read my story [here](./MIM_Personal.md).**


# Parts of a PSMA import script

A PSMA import script consists of **6 main parts**:

* the password.ps1
* the Schema
* control data handed to the script by parameters
* global variables
* the data retrieval from the "external" system
* the mail loop building the output data structure for MIM

Søren Granfeldt gives a clear but maybe a bit rough [overview](https://github.com/sorengranfeldt/psma/wiki/Import) over these parts. Together with Darren Robinson's [instructions](https://blog.darrenjrobinson.com/using-the-new-granfeldt-fim-mim-powershell-management-features/) you can make sense of it, but in my opinion it is still quite a challenge and I want to show you my own approach here, too.

So let me try to break it up and put it together nicely again ...

## 0) Password.ps1

Just to get it over with: even if you do not handle passwords with PSMA, [you **MUST** define a password.ps1](https://github.com/sorengranfeldt/psma/wiki/PasswordManagement) script file for PSMA to work! The name of the file is totally up to you and it can be completely empty if you don't use the feature, but it must exist.

## 1) The Schema

The Schema is a .ps1 file of its own holding a `PSCustomObject` which describes the data set you will return to MIM. Every field you want to import in MIM must be defined there.

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

However, I haven't tested this, yet, and since it has no relevant influence on usability or performance of your PSMA Management Agent, it will remain a matter of taste in my opinion.

**NOTE:**

* The `Anchor` prefix for the field being used as anchor in MIM as well as the different `|type` postfixes are only used in the Schema script! In the import script you keep using 'Id', 'objectClass', 'AccountName', ...!
* The `objectClass` field must be returned for every dataset, so PSMA/MIM can identify where the dataset belongs to. This includes error message you return to MIM from your import or export scripts! More on these later ...

## 2) Parameters
*I am only covering the basic parameters here (the ones I used and therefor had to understand 😉). Please consult Mr Granfeldt's instructions for additional ones*

Parameter|Description
---|---
`$Username` and `$Password`|as they were entered for the Management Agent in MIM. These should be the credentials used to access your external system. **NOTE: the password is sent in clear text!** So I advise against using this parameter pair, if your system can handle SecureString passwords. (VSCode will complain about the use of a plain text $Password parameter, too.)
`$Credentials`|same as above, but already as `[PSCredential]` object, so the password is a SecureString already and you don't have to convert it anymore. 
`$OperationType`|tells your script, if it should do a *FULL* import or a *DELTA* import. It does not do this by itself of course. You have to check for `$OperationType -eq 'FULL'` (not case sensitive) or `$OperationType -eq 'DELTA'`. In fact, you only have to check for one of the two, because if it is not the one, it must be the other and can be taken care of in the `else` clause of your conditional.

This is enough for basic importing to do everything in one run. If you have a lot of data to import, it is recommended to use *paged importing*, which breaks the amount of data in pre-defined chunks, so you don't have to wait for the whole import to finish when e.g. interrupting an import.

Parameter|Description
---|---
`$UsePagedImport`|is the `boolean` flag which MIM sets to `$true` if a paged import is requested.
`$PageSize`|holds the integer number of datasets to process in one run. The script is called multiple times until all the data has been imported. To keep control over where you are in the process you must make use of the `$global` control variables PSMA offers. More about that shortly.

Finally, though I have not used or wrapped my head around it, yet, I want to mention the `$Schema` parameter, which holds the schema data you have defined in the schema.ps1. It offers the possibility to dynamically react to schema changes in your script. For more information about this, please consult Mr Grandfeldt's instructions.


## 3) Global Variables / Control data

PSMA offers a couple of global variables to control your data flow. The first one, `$global:RunStepCustomData`, is the only one generally needed for every type of import, if delta import should be supported, the others are only necessary for *paged import*:

Variable|Description
---|---
`$global:RunStepCustomData`|can hold any data suiting you to save a time stamp for a delta import. The data is saved within MIM/PSMA and can be retrieved on the next run to import only the datasets changed since the latest import.<br>Required for delta imports.<br><br>In some examples online you will find a watermark file written to disk instead of using this variable. I recommend using the variable.
`$global:tenantObjects`|holds all the objects you want to import. You usually pull all your data from the source system into this variable and then import it page by page.<br>Required for paged import.<br><br>If you don't use paged import, you may use any variable you want to hold your data.
`$global:objectsImported`|an integer counter which keeps track of the number of tenantObjects you have processed already.<br>Required for paged import
`$global:PageToken`|an integer counter to keep track of how many tenantObjects you have processed since the current page started. The `$PageSize` parameter must be checked in the import loop for the limit.<br>Required for paged import
`$global:MoreToImport`|a boolean flag which tells PSMA to recall the script for another import page if `$true` or to tell MIM that we are done importing (`$false`).<br>Required for paged import


## 4) Data retrieval

This part is totally up to you. You know your external system best, so use which ever code suits you best to get the data you need into the script.

## 5) The data processing loop

This is were the music plays. Whatever you want to do with your data, it must happen in this loop while processing each and every dataset coming from your input source.

Now, in an ideal world or in the world of a real MIM-Expert, all the import script has to do is take the original data one by one and map it to the fields defined in your Schema.ps1. Even if you need your data to be transformed in any way, it could probably be done using MIM's internal functions, workflows, etc.

However, both is very unlikely if you have not spent a lot of hours learning MIM internals. I didn't, I learned Powershell. :-)

### The classic, code centric approach

In most references about importing scripts I found a copy of Mr Grandfeldt's technique to build the output hashtable for MIM:

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

From a first glance there is nothing bad with this approach. Straight forward, going with the flow, adding the fields as it suits you, then returning the data to MIM.

As I said before, in an ideal world, this actually is all you have to do.

But then you find, your company has different formats for costcenters in different countries which must be harmonized, and since you are not familiar with MIM's internal possibilities or know, you have others in your team knowing Powershell but nobody knowing MIM, you add to the code (don't try to make sense of the resulting data, this is just example code ;-) ) :

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


**Therefor I strongly recommend a different, data centric approach:**

### The data centric approach

In opposition to other automation scripts you may have written, an import script for MIM is not about the code or algorithm but solely about the data!

Let this sink in.

Instead of writing your code in a sequence of processes concentrate on the data you are working with:
1) the data coming into your script
2) the data going out of your script

... and nothing else matters! Not even the sequence in which the data is processed!

Instead of adding each field individually to your output hashtable, **create one hashtable at once** and **use one function for each field**, even if the function just returns a variable unaltered. Just for consistency and ease of maintenance.

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
        $StreetAddress = $dataset.BuildingNr + ' ' + $dataset.Street
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

# Basic Importing Template

```
param(
    [PSCredential]$Credentials,
    [string]$OperationType
)

#-Functions-----------------------------------------

function Get-OutputId {
    $dataset.Id
}

function Get-OutputAccountName {
    $dataset.LastName
}

function Get-OutputDoB {
    $dataset.WhenBorn
}

...

#-General-Preparations------------------------------

    # import modules
    # define variables
    # whatever ..


#-Importing-Data------------------------------------

# save current time right before importing from the source
# you may want to add a .AddMinutes(-1) to the $Now, just in case your two servers' times are a couple of seconds off each other

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
        Id          = Get-OutputId
        AccountName = Get-OutputAccountName
        DoB         = Get-OutputDoB
        ...
    }

    $Output

}
```


# Paged Importing

Now, how to implement paged importing?

Once you have a large amount of datasets to process, paged import adds a certain granularity to the import (and export, but that's a different and far less complicated story).

Let's say you have 10.000 datasets to process. If you do it all in one step you will have to wait until the full batch is processed until you see any result in MIM. Depending on your bandwidth, the amount of data included and the processing done in your script this can take a long time. And you might want to see what is going on during the process, apart from the logging you hopefully have implemented in the script.

### Important code additions

As already discussed in _Parameters_ and _Control Data_ we must use additional control structures in our code to make it ready for paging. Let's review them again:

Control Structure|Purpose
---|---
`[bool]$UsePagedImport`|Tell the script to use paged import (Parameter)
`[int]$PageSize`|The size of each page, means: how many datasets should be processed before giving the control back to MIM/PSMA (Parameter)
`[array]$global:tenantObjects`|The collection of all datasets to be imported
`[int]$global:objectsImported`|Counts, how many datasets have been imported
`[int]$global:PageToken`|Counts, how many datasets have been processed in a single page (must be reset with every page)
`[bool]$global:MoreToImport`|Tells PSMA to call the script again for the next page if there is more data to import or if it may stop importing

### The loop logic

From the description of `$global:MoreToImport` you might already have derived how PSMA is treating paged imports: it calls the import script again for every page! This is also the reason why many of our _Control Data_ variables are of scope `global`, because they **must** survive the script exiting and being called again.

This means we have to make sure that:

* our data is only imported once, like:
```
# make sure we only load import data if it hasn't been done before
if (!$global:tenantObjects) {
    $global:tenantObjects = # whatever you do to get your data
}
```
* we reset the `$global:PageToken` every time we reach the processing loop
* the loop knows where to continue importing when in any page following page 1, when a page is completed and when all `$global:tenantObjects` have been imported. Additionally, it must respect if paged import was asked for, or not, and behave respectively.
* `$global:objectsImported` and `$global:PageToken` get incremented at the end of each iteration and ...
* `$global:MoreToImport` must be set at the end of each page

Quite a lot asked.

The usual way to iterate through a given collection of datasets in Powershell would be the `foreach{}`-Loop, as I used it in the above template for basic importing. However, now we get a lot of conditions the loop must respect. It's not just "run through the whole collection and be gone".<br>
Of course, you could use conditionals within the loop and the `break` statement to quit the operation whenever necessary. But this is a pretty bad approach when it comes to readability and maintainability of the code.

>_"Great, there is a loop!"<br>
>"Wait, there is a break ... and there are more conditions asked ... when the heck does this thing run through at all???"_

Wouldn't it be nice if there was a loop which could do all this for us?

### Enter the `for{}`-Loop

The good old for{}-Loop which generations of developers have learned from their first programming lessons provides all the functionality we need:
* setting a "counter"
* respecting any boolean returning condition to break the loop
* incrementing the counter

... and everything in the loop's head. Nothing to search for, all the information you need in one place, right at the beginning, like:
```
for ($i = 0; $i -lt $array.count; $i++) {
    # whatever
}
```

**Is this cool or what?**

Of course, our's will not be that simple.

First, we cannot just set our counter variable to 0. Whenever our script is run again during paged import the loop must start at the point where it stopped last time. The variable holding this information is `$global:importedObjects`, which is 0 at the beginning of the first call, but is incremented after each loop iteration. So it makes sense to set our counter variable to the value of `$global:importedObjects` whenever the loop starts:

```
for ($i = $global:importedObjects; <# condition #>; $i++) { ... }
```

You probably could skip `$i` all along and just use `$global:importedObjects` as the counter. You would have to set it to itself then for initialization. I prefer this way.

Now to the terminating condition.

First of all we want the loop to run until all our `$global:tenantObjects` have been imported. This is easy:
```
for ($i = $global:importedObjects; $i -lt $global:tenantObjects.Count ... ; $i++) { ... }
```
It should to just this, if `$UsePagedImport` is `$false`. So ...
```
for ($i = $global:importedObjects; $i -lt $global:tenantObjects.Count -and !$RunPagedImport ... ; $i++) { ... }
```
**But** if `$RunPagedImport` is `$true`, it should not only break when everything is done, but also when a page is completed. So _"run to end if no paged import is requested *or* paged import IS requested and the current page is completed"_.

This translates to our final conditional statement in the loop:


```
for ($i = $global:objectsImported; $i -lt $global:tenantObjects.Count -and (!$UsePagedImport -or ($UsePagedImport -and $global:PageToken -lt $PageSize)); $i++) {

    <# processing logic for $global:tenantObject[$i] #>

    # at the end of the loop, increment the tracking counters
    $global:importedObject++
    $global:PageToken++

}
```

Since we are not using a `foreach{}`-Loop you must use classic array syntax to access the current object to be processed, like `$global:tenantObject[$i]`, as I outlined in the block comment in the above snippet.

At the very end of the loop do not forget incrementing our tracking counters, so the script knows, where it is in the process.

### Finishing the paged import

All that is left to do now to complete the paged import code is to set the `$global:MoreToImport` variable and tell MIM/PSMA, if we are done or not. A simple `if` statement:
```
    # Is the number of imported objects still lower then all objects together?
    # Then we have MoreToImport.
    if ($global:objectsImported -lt $global:tenantObjects.Count) {
        $global:MoreToImport = $True
    } else {
        $global:MoreToImport = $False
    }
```

# Paged Importing Template

That's it!

Congratulations! If you have made it up to here, you definitely deserved a templated for paged importing, based on the basic importing templated from above:


```
param(
    [PSCredential]$Credentials,
    [string]$OperationType,
    [bool]$UsePagedImport,
    [int32]$PageSize
)

#-Functions-----------------------------------------

function Get-OutputId {
    $dataset.Id
}

function Get-OutputAccountName {
    $dataset.LastName
}

function Get-OutputDoB {
    $dataset.WhenBorn
}

...

#-General-Preparations------------------------------

    # import modules
    # define variables
    # whatever ..


#-Importing-Data------------------------------------

$Now = [datetime]::Now

# only fetch the data to import at the first run, when $global:tenantObjects is still empty
if (!$global:tenantObjects) {

    if ($OperationType -eq "DELTA" -and $global:RunStepCustomData) {
        $global:tenantObjects = Get-MySourceData -ChangedAfter $global:RunStepCustomData
    } else {
        $global:tenantObjects = Get-MySourceData
    }

    if (($global:tenantObjects -as [array]).count -gt 0) {
        $global:RunStepCustomData = $Now
    }

    # set the import tracking counter to 0
    # also only happens at first run of the script
    # the counter will keep incrementing over all pages
    $global:objectsImported = 0

}


#-Processing-Loop-----------------------------------

# set the page internal counter to 0 before each page starts
$global:PageToken = 0

for ($i = $global:objectsImported; $i -lt $global:tenantObjects.Count -and (!$UsePagedImport -or ($UsePagedImport -and $global:PageToken -lt $PageSize)); $i++) {

    # use a speaking variable name instead of the array element through the rest of the code
    $dataset = $global:tenantObjects[$i]

    $Output = @{
        Id          = Get-OutputId
        AccountName = Get-OutputAccountName
        DoB         = Get-OutputDoB
        ...
    }

    $Output

    # at the end of the loop, increment the tracking counters
    $global:importedObject++
    $global:PageToken++

}


#-Status-Communication-for-PSMA--------------------

# Is the number of imported objects still lower than all objects together?
# Then we have MoreToImport.
if ($global:objectsImported -lt $global:tenantObjects.Count) {
    $global:MoreToImport = $True
} else {
    $global:MoreToImport = $False
}

# END OF SCRIPT
```

---
# Appendix A: Reporting Errors to MIM

When something goes wrong during import (or export) you probably want to post a note back to MIM so it is shown in the Synchronization GUI, like MIM does it during import, sync or export with built-in connectors.

For this you need to hand back the following information packaged in a hashtable, just like your import data:

Data|Description
---|---
objectClass|as defined in your schema
your_anchor|the field you defined as the anchor field for MIM in the schema
anchor_value|the value of the anchor of the failed dataset. This value is shown in the left column of MIM's reporting section. If your script experienced an error unrelated to your data, you can set this field to anything you like (e.g. "ERROR" or "Oops!" or ...)
ErrorName|"Name" is a bit misleading. Use it as a short description shown in the right column of MIM's reporting section, next to the anchor value you defined.
ErrorDetail|any extended information about the error. This information is shown in the dialog which opens in MIM when you click on the posted error.

**Example:**

We have the following dataset:

Field|Value
---|---
objectClass|user
UserName (Anchor)|newton
FirstName|Isaac
LastName|Newt**ö**n

Let's assume the variable holding the data is called `$user`. Your script checks the names, if they use other characters as used by the english alphabet, to be compatible with other services the name is synced to. The "ö" in the LastName obviously doesn't. So you could report back to MIM:

```
@{
    objectClass = 'user'
    UserName = $user.UserName
    [ErrorName] = 'Invalid character'
    [ErrorDetail] = '"LastName" contains a character not matching the english alphabet'
}
```

Don't be confused by the brackets, they are used for MIM-internal, unchangeable fields. You will find more like this when writing export scripts.

As simple as it is, in my opinion it is ugly when being used like this throughout your script. You will probably have more than just one place in your script where you want to post an error, so I recommend wrapping this part in a function and make it flexible enough to be used with all kinds of anchors and objectClasses. This way you can reuse it for different scripts and data.

This is my approach:

```
function New-MIMError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $objectClass,
        [Parameter(Mandatory)]
        [string]
        $AnchorName,
        [Parameter(Mandatory)]
        [string]
        $AnchorValue,
        [Parameter(Mandatory)]
        [string]
        $ErrorName,
        [Parameter(Mandatory)]
        [string]
        $ErrorDetail
    )

    @{
        objectClass = $objectClass
        $AnchorName = $AnchorValue
        '[ErrorName]' = $ErrorName
        '[ErrorDetail]' = $ErrorDetail
    }
}
```

The actual call from our example above would then be:

```
New-MIMError -objectClass 'user' -AnchorName 'UserName' -AnchorValue $user.UserName -ErrorName 'Invalid character' -ErrorDetail '"LastName" contains a character not matching the english alphabet'
```
Not exactly less to type, but i find it still better to understand than a sudden hash definition somewhere in the code.

---
# Appendix B: Logging

This will be a short one:

**Please implement a decent logging in your script!** You will need it more often than you think to find any kind of strange behavior!

If you need a working logging function, feel free to make use of [mine](https://github.com/OtterKring/PS_Write-Log).



<br><br><br>
Happy MIMming!