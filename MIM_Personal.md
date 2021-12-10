# My MIM/PSMA story
last update: Dec. 2021
## Who am I and why am I doing this?

My name is Maximilian Otter, I am working as a System-Expert for Microsoft Exchange and Powershell Automation.

After my finals I studied Organization and Data Processing with focus on Mainframe software development. I found back then that this was not the way of living I wanted to choose for myself and, after a short detour through musical theater, I started my IT career in 2000 as a classic System Administrator. I pursued this path for about 18 years at different companies, providing national and international user support, building networks and domain infrastructures, became self employed for a year until I got hired at my current company in 2011 at a production site.
In 2013 I was transferred to HQ and got trained on Microsoft Exchange which led me to Powershell ... and I immediately caught fire!

I switched from GUI to Powershell for almost everything I am doing, convinced that I could only really learn it, if I made it my day to day work tool. Since then Exchange and Sharepoint have moved to the cloud, Azure Automation became a thing, and (late, though) Microsoft Identity Manager found its way to us, fortunately for me and my skillset in conjunction with PSMA.

## My history with MIM and PSMA

The company I work with introduced MIM to connect the cloud-based HR system Workday with Active Directory and a couple of other systems in 2018. Since this was completely new ground for us I was sent to training for MIM (Fundamentals; thanks goes out to my fabulous trainer and emergency MIM Support [Axel Ciml](https://at.linkedin.com/in/axelciml) ) while an external consultant (not Axel, unfortunately) was hired to build the system.

Long story short, the implementation took longer than expected but finally we managed to go live in time with the project's objective and everything was running ... close to smoothly.

Since then I have been continually monitoring, bug fixing and improving the code, rewritten all but one of the scripts from our consultant in the course of analyzing what they are doing and how they work and finally added my first self written PSMA connection for a Sharepoint list.

This year I found enough time and confidence to take on our main Workday-to-MIM import script. And what I learned in the process along with the information I found in the internet about the topic made me start writing this guide.


## Observations done in the original script

### Brainless copy

After a bit of googling it soon got clear that our consultant copied the basic code for our import script from the [sample given by Darren Robinson](https://blog.darrenjrobinson.com/how-to-configure-paged-imports-on-the-granfeldt-fimmim-powershell-management-agent/) and adapted it to his needs. This is not a bad thing in the first place since, if you dig into Mr Robinson's blog, you will soon accept that he knows what he is talking about. And don't we all copy some code templates now and then?
But what I criticize is that he seems to not actually having analyzed what the code was doing and why. I found lots of code copied from the template and never used during runtime. I also think that there is a better way to do it, which is why I wrote this.

### No structure

Except for the necessity of some logic occurring before the other the code was completely unstructured.
* No function, no obvious regions which were responsible for certain things ... everything was mixed up. Horrible for troubleshooting!
* Output data was filled all over the code, sometimes the same field in multiple places, depending on conditional clauses.
* The main loop broke at the beginning checking a value which was set at the end of the loop. Took me a while to find _this_ relationship!

Lets not continue this.


## My goals for making it better

I decided I wanted my script to:
* be absolutely clear about where which things happen
* data fields to be exported to MIM must be findable by plain eye immediately, with only one place where they are set
* ideally everything should come together to a code structure I could recommend for PSMA import scripts (which it did 🙂)
* it should be "beautiful", or as the austrian architect Otto Wagner put it: "Nothing really practical can every be ugly."


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

## Comment the hell out of your code!

I confess, I don't always do it, especially in small functions. But nevertheless commenting might save you writing a manual or at least save you work doing it, because you already wrote a good deal of it within your code.

And after all ... you might not always be there to maintain your code. Help the poor soul coming after you!

## Structure and format

If it is appealing for the eyes, it is easy to maintain.

Well, maybe not always, but it helps. Nobody wants to deal with ugliness.