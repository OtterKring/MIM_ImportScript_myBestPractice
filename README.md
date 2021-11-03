# Best practice recommendation for writing an Import Script for Microsoft Identity Manager with PSMA

*work in progress*




## PSM... what?

[PSMA is a Management Agent for Microsoft Identity Manager](https://github.com/sorengranfeldt/psma) (MIM, former FIM: "Forefront Identity Manager") created by [Søren Granfeldt](https://github.com/sorengranfeldt) which allows using Powershell scripts to build the bridge between MIM and the systems you want to exchange data with.

There are plenty of Management Agents available for MIM written for specific systems like SAP, Exchange, ActiveDirectory (included in MIM) and many more. PSMA's advantage, and by MIM die-hards often loathed feature, is that you can completely control how the data is transferred between MIM and your system of interest, while not being restricted to a specific API and not having to learn C# or another high level programming language. The only thing necessary is any kind of interface Powershell can use to communicate with your system: an API, a REST web hook, a specific Powershell module, etc.

**If you are interested in my personal approach to the topic, you can read my story [here](./MIM_Personal.md).**


# Parts of a PSMA import script

A PSMA import script consists of **3 main parts**:

* control data handed to the script by parameters
* global variables
* the data retrieval from the "external" system
* the mail loop building the output data structure for MIM

Søren Granfeldt gives a clear but in my opinion very rough [overview](https://github.com/sorengranfeldt/psma/wiki/Import) over these parts. Together with Darren Robinson's [instructions](https://blog.darrenjrobinson.com/using-the-new-granfeldt-fim-mim-powershell-management-features/) you can make sense of it, but in my opinion it is still quite a challenge.

So let me try to break it up ...

## 1) Parameters
*I am only covering the basic parameters here (the ones I used and therefor had to understand 😉). Please consult Mr Granfledt's instructions for additional ones*

* `$Username` and `$Password` as they were entered for the Management Agent in MIM. These should be the credentials used to access your external system. **NOTE: the password is sent in clear text!** So I advise against using this parameter pair, if your system can handle SecureString passwords. (VSCode will complain about the use of a plain text $Password parameter, too.)
* `$Credentials`, same as above, but already as `[PSCredential]` object, so the password is a SecureString already and you don't have to convert it anymore. 
* `$OperationType` tells your script, if it should do a *FULL* import or a *DELTA* import. It does not do this by itself of course. You have to check for `$OperationType -eq 'FULL'` (not case sensitive) or `$OperationType -eq 'DELTA'`. In fact you only have to check for one of the two, because if it is not the one, it must be the other and can be taken care of in the `else` clause of your conditional.
  
This is enough for basic importing to do everything in one run. If you have a lot of data to import, it is recommended to use *paged importing*, which breaks the amount of data in pre-defined chunks, so you don't have to wait for the whole import to finish when e.g. interrupting an import.
It might also be a matter of memory. You don't want to run out of memory because your script is hogging all the data before sending it to MIM.

* `$UsePagedImport` is the `boolean` flag which MIM sets to `$true` if a paged import is requested.
* `$PageSize` holds the integer number of datasets to process in one run. The script is called multiple times until all the data has been imported. To keep control over where you are in the process you must make use of the `$global` control variables PSMA offers. More about that shortly.

Finally, though I have not used or wrapped my head around it, yet, I want to mention the `$Schema` parameter, which holds the schema data you have defined in the schema.ps1. It offers the possibility to dynamically react to schema changes in your script. For more information about this, please consult Mr Grandfeldt's instructions.


## 2) Global Variables / Control data

PSMA offers a couple of global variables to control your data flow. Most of them are only necessary for *paged import*, but one is needed for every import script which should support *DELTA* import:

* `$global:RunStepCustomData`: can hold any data suiting you to save a time stamp for a delta import. The data is saved within MIM/PSMA and can be retrieved on the next run to import only the datasets changed since the latest import.

The following global variables are only used for paged import:

* `$global:tenantObjects`: holds all the objects you want to import. You usually pull all your data from the source system into this variable and then import it page by page.
* `$global:objectsImported`: an integer counter which keeps track of the number of tenantObjects you have processed already.
* `$global:PageToken`: an integer counter to keep track how many tenantObjects you have processed since the current page started. The `$PageSize` parameter must be checked in the import loop for the limit.
* `$global:MoreToImport`: a boolean flag which tells PSMA to recall the script for another import page if `$true` or to tell MIM that we are done importing (`$false`).


## 3) Data retrieval

This part is totally up to you. You know your external system best, so use which ever code suits you best to get the data you need into the script.

## 4) The data processing loop



<hr>

## Basic Importing




## Paged Importing



