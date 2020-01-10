![logo](src/target/ui/images/icon_48.png)

# RoboCopy
This package will help organize your collection of photos and videos into a custom folder structure using rules.

## Rules

Rules specify what actions need to be performed on files.

|Rule field| Meaning |
| --- | --- |
| Priority | Rule execution order. |
| Description | Rule description. |
| Extention | File extension for applying this rule. |
| Source dir | Start folder to search for files. |
| Action | How to process a file: move or copy. |
| Destination folder | Shared destination folder. |
| Destination dir | Destination path. (*Here you can use [value substitution](#values-for-substitution)*) |
| Destination file | The name of the destination file. If empty, the file name will not change. (*Here you can use [value substitution](#values-for-substitution)*) |


### Values for substitution
Values for substitution based on file metadata, they must be indicated by the mustaches (Ex. **{title}**). Value name is ***case sensitive***.

The [Phil Harvey's ExifTool library](http://www.sno.phy.queensu.ca/~phil/exiftool/) is used to obtain file metadata.

<table>
    <tr><th>Name</th><th>Meaning</th><th>Example</th></tr>
    <tr><td colspan="3"><i>Date time file creation</i></td></tr>
    <tr><td>h</td><td>Hour (12-hour clock) as a decimal number.</td><td>7</td></tr>
    <tr><td>hh</td><td>Hour (12-hour clock) as a zero-padded decimal number.</td><td>07</td></tr>
    <tr><td>H</td><td>Hour (24-hour clock) as a decimal number</td><td>7</td></tr>
    <tr><td>HH</td><td>Hour (24-hour clock) as a zero-padded decimal number.</td><td>07</td></tr>
    <tr><td>m</td><td>Minute as a decimal number.</td><td>6</td></tr>
    <tr><td>mm</td><td>Minute as a zero-padded decimal number.</td><td>06</td></tr>
    <tr><td>s</td><td>Second as a decimal number.</td><td>5</td></tr>
    <tr><td>ss</td><td>Second as a zero-padded decimal number.</td><td>05</td></tr>
    <tr><td>tt</td><td>Locale’s equivalent of either AM or PM</td><td>AM</td></tr>
    <tr><td>d</td><td>Day of the month as a decimal number.</td><td>2</td></tr>
    <tr><td>dd</td><td>Day of the month as a zero-padded decimal number.</td><td>02</td></tr>
    <tr><td>ddd</td><td>Weekday as locale’s abbreviated name.</td><td>Mon</td></tr>
    <tr><td>dddd</td><td>Weekday as locale’s full name.</td><td>Monday</td></tr>
    <tr><td>M</td><td>Month as a decimal number.</td><td>9</td></tr>
    <tr><td>MM</td><td>Month as a zero-padded decimal number.</td><td>09</td></tr>
    <tr><td>MMM</td><td>Month as locale’s abbreviated name.</td><td>Sep</td></tr>
    <tr><td>MMMM</td><td>Month as locale’s full name.</td><td>September</td></tr>
    <tr><td>y</td><td>Year without century as a decimal number.</td><td>1</td></tr>
    <tr><td>yy</td><td>Year without century as a zero-padded decimal number.</td><td>01</td></tr>
    <tr><td>yyyy</td><td>Year with century as a decimal number.</td><td>2001</td></tr>
    <tr><td colspan="3"><i>File name</i></td></tr>
    <tr><td>file_ext</td><td>File extension</td><td></td></tr>
    <tr><td>file_dir</td><td>Path to file (without <i>Source dir</i>)</td><td></td></tr>
    <tr><td>file_name</td><td>File name</td><td></td></tr>
    <tr><td colspan="3"><i>Other</i></td></tr>
    <tr><td>title</td><td>Title of composition</td><td></td></tr>
    <tr><td>album</td><td>Album name</td><td></td></tr>
    <tr><td>artist</td><td>Artist name</td><td></td></tr>
    <tr><td>camera_make</td><td>Camera maker name</td><td></td></tr>
    <tr><td>camera_model</td><td>Camera name</td><td></td></tr>
</table>

## Notes

### Requirements

* DSM 4.2 and above
* PERL


### Tested on
- software: DSM 4.2, DSM 4.3, DSM 6.1, DSM 6.2
- hardware: DS209, DS218+


## How to install

**Step 1:** Install standard PERL package

**Step 2:** Download the latest `.spk` from [here](https://github.com/vitaly-s/robocopy/releases/latest)

**Step 3:** Open Package Center in DSM and select the `Manual Install` option.

**Step 4:** Click `Yes` when warned about using a package from an unknown publisher.

**Step 5:** Complete the wizard.

**Step 6:** Use the RoboCopy app icon in the main menu to access the RoboCopy UI where you can manage your setup.


## Build
Download sources and exec make.sh
```
$ sh ./make.sh
```


## Screenshots
![screen shot](ScreenShot.png)

