# Trellis Manual
This is the manual for the usage and basic knowledge for Trellis.

You may find this document useful.

## Basics
Trellis is a very simple templating engine written in Lua.

It works as a console application that is capable of rendering
[extension files](#extension-files) with their respective
[templates](#templates) into a final static text output.

Trellis does not (and will never) have the capability to interface
with programming languages in any sense (like [Jinja](https://jinja.palletsprojects.com/en/stable/), for example).
Trellis is meant to be really bare-bones and as simple as possible.

## File types
Trellis works on two types of files that it can read:
- **Extension files**
- **Template files** (or just **templates**)

> Trellis does not use a specific file extension like programming languages
> or other tools. You can use whatever you want to guarantee proper recognition
> for syntax highlighting in your text editor.

### Templates
Template files are, essentially, a predefined structure or blueprint that combines
static content (normal plain text) with dynamic data ([blocks](#blocks)) to generate a
final output.

Every file that extends from a template always follows the format specified by
the template it's extending from.

Template files can also be extension files because of [template nesting](#template-nesting).

### Extension Files
Extension files are the ones that provide **definitions** for the [blocks](#blocks)
**declared** inside the templates.

> Extension files always extend from exacly one single template file.

## Blocks
Trellis' templating system works by **declaring** and **defining** blocks.

A block **declaration** is expected to be in a [template file](#templates) and
it provides a point in the static text for the block definition to be placed at
during rendering.

When a block is **defined**, the content provided is placed at the place where
the block is declared (in the template file).

## Reference and syntax
Trellis uses `%{` and `}%` to delimit where a directive starts and finishes.

Trellis consists of very simple directives.

- `begin <BLOCK>`
    Begins the definition of a block with name `<BLOCK>`. All text past this is part
    of the defining block's content until an `end` directive is found.
- `template <NAME>`
    Sets the template to be extended from of the current file to
    the template with name `<NAME>`
- `block <NAME>`
    Declares a block position named `<NAME>` inside the file to be
    filled with content later.
- `end`
    Points the end of a block definition

All directives must use the delimiters mentioned before (`%{` and `}%`) to
be interpreted correctly by Trellis.

For example:
- Block definition: `%{begin my_block}% ... %{end}%`
- Block declaration: `%{block my_block}%`
- etc.

## Template nesting
Let's say you want to create a template for a generic page in your website,
something like `Page.html`.

But then you want to introduce a new kind of page that is in the same format
as `Page` but with some more things on top, like `About.html`.

This is a nested template.

In Trellis it is very straight-forward to create nested templates, you basically
use the `template` directive inside another template and this will automatically
behave like a nested template.

## Examples
### Simple example
A template file `page.md` contains the following text:
```md
# %{block title}%
%{block description}%

---

%{block body}%
```

By creating the following `my_page.md` extension file:
```md
%{template page}%

%{begin title}% This is my page %{end}%
%{begin description}% Description of my page %{end}%
%{begin body}%
    Simple content for my page    
%{end}%
```

You should get this as an output
```md
#  This is my page 
 Description of my page 

---


    Simple content for my page    

```

### Nested template example
You have 2 templates that are nested, `Page.html` and `DocumentationPage.html`.

`Page.html`:
```html
<title>%{block title}%</title>
<body>
    <main>
        %{block body}%
    </main>
    <footer>
        (c) 2025 Trellis
    </footer>
</body>
```

`Page.html`:
```html
%{template Page}%
%{begin title}%
   Documentation | %{block title}%
%{end}%
%{begin body}%
    <div>
        <p>Documentation Page</p>
        %{block body}%
    </div>
%{end}%
```

With an extension file like this:
```html
%{template DocumentationPage}%
%{begin title}%Fizz Buzz%{end}%
%{begin body}%
lorem ipsum dolor
%{end}%
```

You get this as the rendered output:
```html
<title>Documentation | Fizz Buzz</title>
<body>
    <main>
        <div>
            <p>Documentation Page</p>
            
            lorem ipsum dolor
            
        </div>
    </main>
    <footer>
        (c) 2025 Trellis
    </footer>
</body>
```

> For more examples, visit the [proper folder](./examples/) for those.
