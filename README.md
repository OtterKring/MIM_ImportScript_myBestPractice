# My experience with PSMA for MIM, Powershell Agent for Microsoft Idenitity Manager

*work in progress*

## Introduction

### Who am I and why am I doing this?

My name is Maximilian Otter, I am working as a System-Expert for Microsoft Exchange and Powershell Automation

After my finals I studied Organization and Data Processing with focus on Mainframe software development. I found back then that this was not the way of living I wanted to choose for myself and, after a short detour through musical theater, I started my IT career in 2000 as a classic System Administrator. I pursued this path for about 18 years at different companies, providing national and international user support, building networks and domain infrastructures, became self employed for a year until I got hired at my current company in 2011 at a production site.
In 2013 I was transferred to HQ and got trained on Microsoft Exchange which led me to Powershell ... and I immediately caught fire!

I switched from GUI to Powershell for almost everything I am doing, convinced that I could only really learn it, if I make it my day to day work tool. Since then Exchange and Sharepoint have moved to the cloud, Azure Automation became a thing, and (late, though) Microsoft Identity Manager found its way to us, fortunately for me and my skillset in conjunction with PSMA.


### PSM... what?

[PSMA is a Management Agent for Microsoft Identity Manager](https://github.com/sorengranfeldt/psma) (MIM, former FIM: "Forefront Identity Manager") created by Søren Granfeldt which allows using Powershell scripts to build the bridge between MIM and the systems you want to exchange data with.

There are plenty of Management Agents available for MIM written for specific systems like SAP, Exchange, ActiveDirectory (included in MIM) and many more. PSMA's advantage is that you can completely control how the data is transferred between MIM and your system of interest, while not being restricted to a specific API. The only thing necessary is any kind of interface Powershell can use to communicate with your system: an API, a REST web hook, a specific Powershell module, etc.

### My history with MIM and PSMA

The company I work with introduced MIM to connect the cloud-based HR system Workday with Active Directory and a couple of other systems in 2018. Since this was completely new ground for us I was sent to training for MIM (Fundamentals; thanks goes out to my fabulous trainer and emergency MIM Support [Axel Ciml](https://at.linkedin.com/in/axelciml) ) while an external consultant (not Axel, unfortunately) was hired to build the system.

Long story short, the implementation took longer than expected but finally we managed to go live in time with the project's objective and everything was running ... close to smoothly.

Since then I have been continually monitoring, bug fixing and improving the code, rewritten all but one of the scripts from our consultant in the course of analyzing what they are doing and how they work and finally added my first self written PSMA connection for a Sharepoint list.

This year I found enough time and confidence to take on our main Workday-to-MIM import script. And what I learned in the process along with the information I found in the internet about the topic made me start writing this guide.


## STARTING FROM SCRATCH: Observations done in the original script

### Brainless copy

After a bit of googling it soon got clear that our consultant copied the basic code for our import script from the [sample given by Darren Robinson](https://blog.darrenjrobinson.com/how-to-configure-paged-imports-on-the-granfeldt-fimmim-powershell-management-agent/) and adapted it to his needs. This is not a bad thing in the first place since, if you dig into Mr Robinson's blog you will soon accept that he knows what he is talking about. And don't we all copy some code templates now and then?
What I also realized after digging in to the code was, that he did not really think about what the code was doing and why it was written that way and ... if there eventually was a better way to do it. There was code copied from the template and never used during runtime.

### No structure

Except for the necessity of some logic occurring before the other the code was completely unstructured.
* No function, no obvious regions which were responsible for certain things ... everything was mixed up.
* Output data was filled all over the code, sometimes overwritten again.
* The main loop broke at the beginning checking a value which was set at the end of the loop

... lets not continue this


### My goals

I decided I wanted my script to:
* be absolutely clear about where which things happen
* data fields to be exported to MIM must be findable by plain eye immediately, which only one place where they are set
* ideally everything should come together to a code structure I could recommend for PSMA import scripts (which it did 🙂)
* it should be "beautiful", or as the austrian architect Otto Wagner put it: "Nothing really practical can every be ugly."


## HOW TO Import with PSMA

### Parts of a PSMA import script

A PSMA import script consists of **3 main parts**:

* control data handed to the script by parameters or global variables
* the data retrieval from the "external" system
* the mail loop building the output data structure for MIM

Søren Granfeldt gives a clear but in my opinion very rough [overview](https://github.com/sorengranfeldt/psma/wiki/Import) over these parts. Together with Darren Robinson's [instructions](https://blog.darrenjrobinson.com/using-the-new-granfeldt-fim-mim-powershell-management-features/) you can make sense of it, but in my opinion it is still quite a challenge.

So let me try to break it up ...

#### Parameters
*I am only covering the basic parameters here (the ones I used and therefor had to understand 😉). Please consult Mr Granfledt's instructions for additional ones*

* `$Username` and `$Password` as they were entered for the Management Agent in MIM. These should be the credentials used to access your external system. **NOTE:** the password is sent in clear text! So I advise against using this parameter pair, if you system can handle SecureString passwords.
* `$Credentials`, same as above, but already as `[PSCredential]` object, so the password is a SecureString already and you don't have to convert it anymore. 
* `$OperationType` tells your script, if it should do a FULL import or a DELTA import. It does not do this by itself of course. You have to check for `$OperationType -eq 'FULL'` (not case sensitive) or `$OperationType -eq 'DELTA'`. In fact you only have to check for one of the two, because if it is not the one it must be the other and can be take care of in the `else` clause of your conditional.
  
This is enough for basic importing to do everything in one run. If you have a lot of data to import, it is recommended to use *paged importing*, which breaks the amount of data in pre-defined chunks, so you don't have to wait for the whole import to finish when e.g. interrupting an import.
It might also be a matter of memory. You don't want to run out of memory because you script is hogging all the data before sending it to MIM.

* `$UsePagedImport` is the `boolean` flag which MIM sets to `$true` if a paged import is requested.
* `$PageSize` holds the integer number of datasets to process in one run. The script is called multiple times until all the data has been imported. To keep control over where you are in the process you must make use of the `$global` control variables PSMA offers. More about that shortly.

Finally, though I have not used or wrapped my head around it, yet, I want to mention the `$Schema` parameter, which holds the schema data you have defined in the schema.ps1. It offers the possibility to dynamically react to schema changes in your script. For more information about this, please consult Mr Grandfeldt's instructions.


### Global Variables / Control data



## Basic Importing


## Paged Importing



# APPENDIX: Coding rules

When taking my developer classes in the 90s (IBM-370 Assembler, C/C++, PL/1, Cobol, ...) we were instructed to follow a couple of rules. Most of them might be outdated nowadays in terms of performance or functionality considerations, but they have one big thing in common: readability and maintainability of your code. The rules I still remember and try to follow were:

## Don't break a loop if you can use the loop logic to do it.

There are several kinds of loops to suit your needs, so from my experience you can get around a break in most cases (in loops at least, not in switch statements). e.g.:
   
**BAD** (very scripting-like approach)
```
foreach ($obj in $collection) {
    ...
    if ($obj -eq 'Steve') {break}
}
```

**GOOD**
```
for ($i = 0; $i -lt ($collection -as [array]).count -and $obj -ne 'Steve'; $i++) {
    $obj = $collection[$i]
    ...
}
```

*Why are breaks a bad thing?* you may ask. Well, they can hide *everywhere* in the code, in unlimited amounts, and are easily overlooked. It makes trouble shooting unnecessarily difficult.
A clear break rule in the loop logic might need some brain activity to figure out at first, but once written it is a clear statement without questions asked.


## Don't use conditionals if you can replace it by a direct action

This was a performance thing in IBM-370 assembler because every branching operation took more cpu cycles and any other straight operational statement.

Examples:
```
$flag = $isLicensed -and $accountEnabled
```
... instead of ...
```
if ($isLicensed -and $accountEnabled) {
    $flag = $true
} else {
    $flag = $false
}
```

Often math operations like modulo (`x % y`) can avoid conditionals, too.

This is not a performance thing anymore in high level or scripting languages. But it shortens your code.

## (there was another rule I cannot remember right now)


