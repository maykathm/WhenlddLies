# When `ldd` Lies: Wading through symbol hijacking and conflicting library versions with a toy C++/CMake application on Linux

Say you've built an application in your build environment and deploy it, together with some dependencies, to a different environment. You double check with `ldd` that all your dependencies are in order and even check to make sure the environment doesn't have any potential conflicts like wayward libraries with the same name installed in `/usr/bin`. You launch your application and boom, seg fault. What the...?

## This repo is all about that "What the...?"

Let's start going by back to the basics, shall we?

## Very brief explanation of how a program is executed on Linux


Let's say one is writing a C++ application that contains dynamic libraries. One might have various libraries and executables (like in this toy application) that all interlock to satisfy the  purpose of the application's existence. To go from source files filled with human-readable text and symbols to a machine execution involves compilation, static linking, and dynamic linking.

### Compilation

For those unfamiliar with the concept, compilations involves transforming a human-readable file with cute commands like `printf("Hello, world!\n")` into something the machine can execute.

### Static linking

This stage involves linking bits of previously compiled code together into a final product. It's basically a chef, putting together ingredients here and there: "Give me a bit of `libc`, some `libgcc`, and a touch of `libcoolness`, mix it all together with some relocations, symbol definitions, memory offsets, and we got ourselves an application."

Here's where the confusion begins, and one might get lulled into a false sense of security. One might figure that so long as this stage reflects what execution should look like, everything should be just fine. Everything *could* be just fine, so long as we keep in mind what happens next.

### Dynamic linking

During execution, the dynamic linker decides which files containing code effectively get loaded and makes definition-to-calling-reference symbol associations across the code to be executed.

#### Which libraries to load?

Given a library of a certain name, `libexample.so`, if during execution the dynamic linker determines that library is required, it begins searching for it using a predefined strategy that one can read about in the man pages of `ld`. It goes through folders looking for a file of that name, `libexample.so`. The first instance it finds, it loads.

#### What about symbols?

Symbols identify a section of code. During execution, the dynamic linker works to associate symbol references (for instance, a library that wants to call a function in another library) to their definitions. Multiple symbol definitions can exist in a single execution context, as we will see in this repo.

For a great in-depth explanation of a linker, I highly recommend Ian Lance Taylor's series of [blog posts](https://www.airs.com/blog/archives/38).


## Repo contents

|Folder|Contents Description|
|-|-|
|`environments`|Contains build scripts and a Dockerfile that will build all attempts in an Ubuntu image. |
|`common`|Folder for the common dependency library|
|`kwel`|Folder for kwel plugin interface header-only library|
|`plugin`|Folder for the plugin portion of the application|
|`main`|Folder for main executable section|

## How to use the environment

All of the commands in the hypothetical scenario that follows can be run in the supplied environment.

### Step 1 - Build the Docker image

```bash
docker build -t <image-name> .
```

### Step 2 - Create the Docker container

```bash
docker create --name <container-name> -it <image-name>
```

### Use the environment by starting up the container and attaching to it
```bash
docker start <container-name>
docker attach <container-name>
```
or
```bash
docker start -i <container-name>
```

If you are a VS Code user, I would recommend using dev containers so you can play around with this toy application with the benefit of a GUI.

## Built environment contents

Assuming one has built the Docker image and created a container, one will find the following:

In opt, we find the various installs of the common dependency, the kwel plugin interface, the various installs for main, as well as a gdb extension: pwndbg.
```console
root@feadq71ea643:/# ls /opt/
common1  common1SV  common1V  common2  common2SV  common2V  kwel  mains  pwndbg
```
The bin folder in the main installation has all the attempts that will be used, while the lib folder contains main's `SoKwel` library.
```console
root@feadq71ea643:/# ls /opt/mains/bin/
attempt1  attempt2  attempt3  attempt4  attempt5  attempt6
root@feadq71ea643:/# ls /opt/mains/lib/
libso_kwel.so
```
In `/usr/local/lib`, we find various versions of the plugin installed with a descriptive name (`_s` indicates that it links to a version of the common library with versioned symbols while `_v` indicates linking to one with a `SONAME` that contains the major version).
```console
root@feadq71ea643:/# ls /usr/local/lib/
libplugin_hidden_symbols_s_v.so  libplugin_visible_symbols.so      libplugin_visible_symbols_v.so
libplugin_hidden_symbols_v.so    libplugin_visible_symbols_s_v.so  python3.10
```

## Table of contents of attempts
1. [Attempt 1](#attempt-1)
2. [Attempt 2 - The scorched earth approach with `dlmopen`](#attempt-2---the-scorched-earth-approach-with-dlmopen)
3. [Attempt 3 - Favor local scope for symbol resolution over global with `RTLD_DEEPBIND`](#attempt-3---use-rtld_deepbind-in-dlopen-to-place-the-plugins-local-scope-symbol-lookup-ahead-of-global-scope)
4. [Attempt 4 - Add a SONAME with symbolic links for common library](#attempt-4---use-rtld_deepbind-with-versioned-common-library)
5. [Attempt 5 - Hide all symbols in plugin except for `getPlugin`](#attempt-5---hide-symbols-in-plugin)
6. [Attempt 6 - Add versions to symbols in the common library](#attempt-6---add-versions-to-common-dependency-symbols)

## Hypothetical environment conditions

<image src="diagrams/overall_diagram.svg"/>

### In this hypothetical environment, we find ourselves in the following mess:
- One team develops a common dependency (common), used by multiple libraries and executables on the system, with multiple versions.
- There is a common shared plugin interface (kwel) that both the plugin team and the plugin users must use
- One team develops a plugin (plugin), accessible through the interface (kwel), that depends upon the common dependency (common) version 2.
- One team develops the plugin user executable (main) that dynamically loads the plugin library (plugin), interacts with it through its interface (kwel), and also depends upon the common dependency (common) version 1.
- The plugin team and the plugin user team are required to use the same namespace, kwel.

### Desired correct behavior

```console
root@feadq71ea643:/# ./main
SoKwel in plugin says so kwel
I am the common dependency version 2
SoKwel in main says so kwel
I am the common dependency version 1
```
<image src="diagrams/desired_functionality.svg" />

### Key bits of code

#### Common Dependency

`common/CommonDependency.h`
```c++
namespace common {
    class CommonDependency {
    public:
        void sayHello();
    };
}
```

`common/CommonDependencyv1.cpp`
```c++
namespace common {
    void CommonDependency::sayHello() {
        printf("I am the common dependency version 1\n");
    }
}
```

`common/CommonDependencyv2.cpp`
```c++
namespace common {
    void CommonDependency::sayHello() {
        printf("I am the common dependency version 2\n");
    }
}
```

#### Kwel Plugin Interface

`kwel/KwelPluginInterface.h`
```c++
namespace kwel {
    class KwelPluginInterface {
    public:
        virtual ~KwelPluginInterface() = default;
        virtual void doThings() const = 0;
    };
}
```

#### Plugin

`plugin/Plugin.h`
```c++
namespace kwel {
    class Plugin : public kwel::KwelPluginInterface {
        void doThings() const override;
    };
}
extern "C" {
    __attribute__((visibility("default"))) kwel::KwelPluginInterface* getPlugin() {
        return new kwel::Plugin();
    }
}
```
`plugin/Plugin.cpp`
```c++
namespace kwel {
    void Plugin::doThings() const {
        SoKwel soKwel;
        soKwel.soKwel();
        common::CommonDependency common;
        common.sayHello();
    }
}
```
`plugin/SoKwel.h`
```c++
namespace kwel {
    class SoKwel {
    public:
        void soKwel();
    };
}
```
`plugin/SoKwel.cpp`
```c++
namespace kwel {
    void SoKwel::soKwel() {
        printf("SoKwel in plugin says so kwel\n");
    }
}
```

#### Main
`main/main.cpp`
```c++

int main(int argc, char* argv[]) {
    void* library = dlopen("libplugin_visible_symbols.so", RTLD_LAZY);
    if (library == nullptr) {
        printf("The plugin library was not found.\n");
        return EXIT_FAILURE;
    }
    auto func = reinterpret_cast<kwel::KwelPluginInterface *(*)()>(dlsym(library, "getPlugin"));
    if (func == nullptr) {
        printf("The getPlugin symbol was not found in the plugin library\n");
        dlclose(library);
        return EXIT_FAILURE;
    }
    auto things(std::shared_ptr<kwel::KwelPluginInterface>(func(), [library](kwel::KwelPluginInterface *p){delete p; dlclose(library);}));
    things->doThings();
    kwel::SoKwel soKwel;
    soKwel.soKwel();
    common::CommonDependency common;
    common.sayHello();
    return EXIT_SUCCESS;
}
```

`main/SoKwel.h`
```c++
namespace kwel {
    class SoKwel {
    public:
        void soKwel();
    };
}
```

`main/SoKwel.cpp`
```c++
namespace kwel {
    void SoKwel::soKwel() {
        printf("SoKwel in main says so kwel\n");
    }
}
```

## Attempt 1

### Configuration Summary
- Both plugin and main link to a `libcommon.so`, though of different versions.
- The plugin exports all symbols.

**Involved files**

|File|Description|
|-|-|
|`/opt/mains/bin/attempt1`|Main executable - uses common v1|
|`/usr/local/lib/libplugin_visible_symbols.so`|Plugin installation - uses common v2|
|`/opt/common1/lib/libcommon.so`|Common dependency version 1|
|`/opt/common2/lib/libcommon.so`|Common dependency version 2|

### Program output:
```console
root@feadq71ea643:/# /opt/mains/bin/attempt1
Getting ready to load plugin libplugin_visible_symbols.so
SoKwel in main says so kwel
I am the common dependency version 1
SoKwel in main says so kwel
I am the common dependency version 1
```

<image src="diagrams/attempt1.svg" />

### What's happening?

- **Problem 1:** The plugin's use of its own personal soKwel method inside its SoKwel class got hijacked by main's SoKwel::soKwel implementation.
- **Problem 2:** The plugin's dependency on Common Dependency v2.0.0 didn't get respected and wound up getting mixed up in main's dependency.



### Problem 1 - kwel::SoKwel::soKwel symbol collision

This is what we get for using the same namespace across multiple products. Both the executable team and the plugin team independently, without the other's knowledge, chose to add a class called `SoKwel` with a method `soKwel`. That means that both products then in their ELF output have the exact same symbol, `_ZN4kwel6SoKwel6soKwelEv`. So when that symbol gets bound at the executable's scope, if it's exposed in the plugin, it will use the same binding.

Let's see if the symbol is in fact present as a dynamic symbol to be resolved in the file:

```console
root@feadq71ea643:/# readelf -W --dyn-syms /usr/local/lib/libplugin_visible_symbols.so 

Symbol table '.dynsym' contains 26 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name

..<SNIP>..

    16: 00000000000012d0    16 FUNC    GLOBAL DEFAULT   14 _ZN4kwel6SoKwel6soKwelEv
```

There it is with global binding. Let's see it also in the main:

```console
root@feadq71ea643:/# readelf -W --dyn-syms /opt/mains/bin/attempt1 | grep soKwel
    25: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _ZN4kwel6SoKwel6soKwelEv
```

Yep, same symbol with global binding yet they want to reference different things. Sounds like a recipe for disaster.

We can re-run the executable with some debug information for bindings to confirm the hypothesis:

```console
root@feadq71ea643:/# LD_DEBUG=bindings /opt/mains/bin/attempt1 2>&1 | grep 'soKwel'
        20:	binding file /opt/mains/bin/attempt1 [0] to /opt/mains/lib/libso_kwel.so [0]: normal symbol `_ZN4kwel6SoKwel6soKwelEv'
        20:	binding file /usr/local/lib/libplugin_visible_symbols.so [0] to /opt/mains/lib/libso_kwel.so [0]: normal symbol `_ZN4kwel6SoKwel6soKwelEv'
```

It looks like first the symbol `_ZN4kwel6SoKwel6soKwelEv` (which demangled is namespace kwel, class SoKwel, method soKwel with its signature) from main gets bound to its dependency found at `/opt/mains/lib/libso_kwel.so` and then the linker applies the same resolution to the plugin. We want the plugin to instead call its own soKwel method.

### Problem 2 - wrong `libcommon.so` gets used


#### Did we build the application correctly? Is the static link correct?

First of all, we should verify that both the main and the plugin in fact link to their respective correct libcommon and that the libcommon they link to was also built correctly.

```console
root@feadq71ea643:/# ldd /usr/local/lib/libplugin_visible_symbols.so  | grep common
	libcommon.so => /opt/common2/lib/libcommon.so (0x00007ff09018d000)
root@feadq71ea643:/# strings /opt/common2/lib/libcommon.so | grep "common dependency"
I am the common dependency version 2
```
 and the executable:
```console
root@feadq71ea643:/# ldd /opt/mains/bin/attempt1 | grep common
	libcommon.so => /opt/common1/lib/libcommon.so (0x00007fdddd420000)
root@feadq71ea643:/# strings /opt/common1/lib/libcommon.so | grep "common dependency"
I am the common dependency version 1

```

Yes. The programs were linked correctly and version 2 prints that it is version 2 while version 1 prints that it is version1. So we don't have any building misconfigurations.

#### What does the dynamic linker do?

First let's verify that it loads the library found at `/opt/common2/lib/libcommon.so`
```console
root@feadq71ea643:/# LD_DEBUG=libs /opt/mains/bin/attempt1 2>&1 1>/dev/null | grep common2
root@feadq71ea643:/#
```
No. It looks like the `/opt/common2/lib/libcommon.so` doesn't even get loaded.

`/opt/common1/lib/libcommon.so`, on the other hand, does:

```console
root@feadq71ea643:/# LD_DEBUG=libs /opt/mains/bin/attempt1 2>&1 1>/dev/null | grep libcommon.so
        78:	find library=libcommon.so [0]; searching
        78:	  trying file=/opt/mains/lib/glibc-hwcaps/x86-64-v3/libcommon.so
        78:	  trying file=/opt/mains/lib/glibc-hwcaps/x86-64-v2/libcommon.so
        78:	  trying file=/opt/mains/lib/tls/haswell/x86_64/libcommon.so
        78:	  trying file=/opt/mains/lib/tls/haswell/libcommon.so
        78:	  trying file=/opt/mains/lib/tls/x86_64/libcommon.so
        78:	  trying file=/opt/mains/lib/tls/libcommon.so
        78:	  trying file=/opt/mains/lib/haswell/x86_64/libcommon.so
        78:	  trying file=/opt/mains/lib/haswell/libcommon.so
        78:	  trying file=/opt/mains/lib/x86_64/libcommon.so
        78:	  trying file=/opt/mains/lib/libcommon.so
        78:	  trying file=/opt/common1/lib/glibc-hwcaps/x86-64-v3/libcommon.so
        78:	  trying file=/opt/common1/lib/glibc-hwcaps/x86-64-v2/libcommon.so
        78:	  trying file=/opt/common1/lib/tls/haswell/x86_64/libcommon.so
        78:	  trying file=/opt/common1/lib/tls/haswell/libcommon.so
        78:	  trying file=/opt/common1/lib/tls/x86_64/libcommon.so
        78:	  trying file=/opt/common1/lib/tls/libcommon.so
        78:	  trying file=/opt/common1/lib/haswell/x86_64/libcommon.so
        78:	  trying file=/opt/common1/lib/haswell/libcommon.so
        78:	  trying file=/opt/common1/lib/x86_64/libcommon.so
        78:	  trying file=/opt/common1/lib/libcommon.so
        78:	calling init: /opt/common1/lib/libcommon.so
        78:	calling fini: /opt/common1/lib/libcommon.so [0]
```

If we didn't think before, now look at what the linker is doing should make our problem obvious. The dynamic linker uses a name-based search to find dependencies. So when we supply the same library name, `libcommon.so`, there is no way for the linker to figure out that we actually want two different libraries. 

Fortunately, we have a mechanism we can use:
- We create a symbolic link that includes version information and have it link to the library.
- We change the `SONAME` entry in the ELF file to say anyone who links to this library should use that symbolic link instead of `libcommon.so`.

We'll see that mechanism in play in [Attempt 4](#attempt-4---use-rtld_deepbind-with-versioned-common-library)

## Attempt 2 - The scorched earth approach with `dlmopen`

### Configuration Summary
- Both plugin and main link to a `libcommon.so`, though of different versions.
- The plugin exports all symbols.
- Instead of using `dlopen`, the main loads the plugin with `dlmopen`

**Involved files**

|File|Description|
|-|-|
|`/opt/mains/bin/attempt2`|Main executable - uses common v1|
|`/usr/local/lib/libplugin_visible_symbols.so`|Plugin installation - uses common v2|
|`/opt/common1/lib/libcommon.so`|Common dependency version 1|
|`/opt/common2/lib/libcommon.so`|Common dependency version 2|

#### Code changes
`main/main.cpp`

```diff
-   void* library = dlopen("libplugin_visible_symbols.so", RTLD_LAZY);
+   void* library = dlmopen(LM_ID_NEWLM, "libplugin_visible_symbols.so", RTLD_LAZY);
```

### Program output
```console
root@feadq71ea643:/# /opt/mains/bin/attempt2
Getting ready to load plugin libplugin_visible_symbols.so
SoKwel in plugin says so kwel
I am the common dependency version 2
SoKwel in main says so kwel
I am the common dependency version 1
```

<image src="diagrams/dlmopen.svg" />

#### It worked! We got the correct output. Let's pack it in. Or... wait, why did it work?

Reading the man pages for `dlmopen`, it becomes pretty obvious why it did work, coming on the heels of our previous analysis.

```
       The dlmopen() function permits object-load isolation—the ability
       to load a shared object in a new namespace without exposing the
       rest of the application to the symbols made available by the new
       object.

..<SNIP>..

       Possible uses of dlmopen() are plugins where the author of the
       plugin-loading framework can't trust the plugin authors and does
       not wish any undefined symbols from the plugin framework to be
       resolved to plugin symbols. Another use is to load the same
       object more than once.
```

### Ok, actually it sounds like using `dlmopen` is probably overkill and could hurt us later on because:
- The man pages don't describe our situation. Main can trust the plugin and the plugin doesn't need total isolation.
- Total isolation is probably a bad idea. In the very near future, we will need to pass objects between main and the plugin. If the plugin is isolated in a different namespace, that will not be possible.
- The total isolation probably means we're being bad memory stewards because that would imply a separate copy of *everything* loaded for the plugin. Let's verify that using `pwndbg`.

```console
root@feadq71ea643:/# gdb /opt/mains/bin/attempt2 

..<SNIP>..

pwndbg> disass main
Dump of assembler code for function main:

..<SNIP>..

   0x000000000000272f <+591>:	lea    rax,[rip+0x24fa]        # 0x4c30 <_ZTVSt19_Sp_counted_deleterIPN4kwel19KwelPluginInterfaceEZ4mainEUlS2_E_SaIvELN9__gnu_cxx12_Lock_policyE2EE+16>
```

`main+591` looks like a good spot to put a breakpoint and check out the memory situation. We can look at the process' memory occupation by using the `vmmap` command. A `-x` flag will print out only the executable sections. Since each library has code, data, and rodata sections, by requesting only the code sections, we can avoid repetitions since we're only interested in what libraries are loaded.

```console
pwndbg> b *main+591
Breakpoint 1 at 0x272f
pwndbg> r

..<SNIP>..

pwndbg> vmmap -x
LEGEND: STACK | HEAP | CODE | DATA | RWX | RODATA
             Start                End Perm     Size Offset File
    0x555555556000     0x555555557000 r-xp     1000   2000 /opt/mains/bin/attempt2
    0x7ffff74e8000     0x7ffff74ff000 r-xp    17000   3000 /usr/lib/x86_64-linux-gnu/libgcc_s.so.1
    0x7ffff7513000     0x7ffff758f000 r-xp    7c000   e000 /usr/lib/x86_64-linux-gnu/libm.so.6
    0x7ffff7614000     0x7ffff77a9000 r-xp   195000  28000 /usr/lib/x86_64-linux-gnu/libc.so.6
    0x7ffff78af000     0x7ffff79c0000 r-xp   111000  9a000 /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.30
    0x7ffff7a42000     0x7ffff7a43000 r-xp     1000   1000 /opt/common2/lib/libcommon.so
    0x7ffff7a47000     0x7ffff7a48000 r-xp     1000   1000 /usr/local/lib/libplugin_visible_symbols.so
    0x7ffff7a5c000     0x7ffff7ad8000 r-xp    7c000   e000 /usr/lib/x86_64-linux-gnu/libm.so.6
    0x7ffff7b5f000     0x7ffff7cf4000 r-xp   195000  28000 /usr/lib/x86_64-linux-gnu/libc.so.6
    0x7ffff7d63000     0x7ffff7d7a000 r-xp    17000   3000 /usr/lib/x86_64-linux-gnu/libgcc_s.so.1
    0x7ffff7e1a000     0x7ffff7f2b000 r-xp   111000  9a000 /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.30
    0x7ffff7fb2000     0x7ffff7fb3000 r-xp     1000   1000 /opt/mains/lib/libso_kwel.so
    0x7ffff7fb7000     0x7ffff7fb8000 r-xp     1000   1000 /opt/common1V/lib/libcommon.so.1.0.0
    0x7ffff7fc1000     0x7ffff7fc3000 r-xp     2000      0 [vdso]
    0x7ffff7fc5000     0x7ffff7fef000 r-xp    2a000   2000 /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
0xffffffffff600000 0xffffffffff601000 r-xp     1000      0 [vsyscall]
pwndbg> 
```

`glibc` is loaded twice, along with `libgcc` and `libstdc++`. That's a bad use of memory. In terms of memory, it's like we're making the plugin into a static archive.

As a reference, if we were to do the same procedure on the previous attempt, we would find the following:
```console
pwndbg> vmmap -x
LEGEND: STACK | HEAP | CODE | DATA | RWX | RODATA
             Start                End Perm     Size Offset File
    0x555555556000     0x555555557000 r-xp     1000   2000 /opt/mains/bin/attempt1
    0x7ffff7a47000     0x7ffff7a48000 r-xp     1000   1000 /usr/local/lib/libplugin_visible_symbols.so
    0x7ffff7a5c000     0x7ffff7ad8000 r-xp    7c000   e000 /usr/lib/x86_64-linux-gnu/libm.so.6
    0x7ffff7b5f000     0x7ffff7cf4000 r-xp   195000  28000 /usr/lib/x86_64-linux-gnu/libc.so.6
    0x7ffff7d63000     0x7ffff7d7a000 r-xp    17000   3000 /usr/lib/x86_64-linux-gnu/libgcc_s.so.1
    0x7ffff7e1a000     0x7ffff7f2b000 r-xp   111000  9a000 /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.30
    0x7ffff7fb2000     0x7ffff7fb3000 r-xp     1000   1000 /opt/mains/lib/libso_kwel.so
    0x7ffff7fb7000     0x7ffff7fb8000 r-xp     1000   1000 /opt/common1/lib/libcommon.so
    0x7ffff7fc1000     0x7ffff7fc3000 r-xp     2000      0 [vdso]
    0x7ffff7fc5000     0x7ffff7fef000 r-xp    2a000   2000 /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
0xffffffffff600000 0xffffffffff601000 r-xp     1000      0 [vsyscall]
```

### Scrap that. Back to the drawing board.

## Attempt 3 - use `RTLD_DEEPBIND` in `dlopen` to place the plugin's local scope symbol lookup ahead of global scope

### Configuration Summary
- Main uses `dlopen` with the `RTLD_DEEPBIND` option to somewhat isolate the dynamically loaded library
- Both plugin and main link to a `libcommon.so`, though of different versions.
- The plugin exports all symbols.

**Involved files**

|File|Description|
|-|-|
|`/opt/mains/bin/attempt3`|Main executable - uses common v1|
|`/usr/local/lib/libplugin_visible_symbols.so`|Plugin installation - uses common v2|
|`/opt/common1/lib/libcommon.so`|Common dependency version 1|
|`/opt/common2/lib/libcommon.so`|Common dependency version 2|

#### Code Changes

`main/main.cpp`
```diff
-   void* library = dlmopen(LM_ID_NEWLM, "libplugin_visible_symbols.so", RTLD_LAZY);
+   void* library = dlopen("libplugin_visible_symbols.so", RTLD_LAZY | RTLD_DEEPBIND);
```

### Program output
```console
root@feadq71ea643:/# /opt/mains/bin/attempt3
Getting read to load plugin libplugin_visible_symbols.so
SoKwel in Plugin says so kwel
I am the common dependency version 1
SoKwel in main says so kwel
I am the common dependency version 1
```

<image src="diagrams/attempt3.svg" />

### Why does `RTLD_DEEPBIND` solve the `SoKwel` symbol collision problem?

The symbol situation has not changed. If we look at the plugin and executable ELFs:

```console
root@feadq71ea643:/# readelf -W --dyn-sym /usr/local/lib/libplugin_visible_symbols.so | grep soKwel
    16: 00000000000012d0    16 FUNC    GLOBAL DEFAULT   14 _ZN4kwel6SoKwel6soKwelEv
root@feadq71ea643:/# readelf -W --dyn-sym /opt/mains/bin/attempt3 | grep soKwel
    25: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _ZN4kwel6SoKwel6soKwelEv
```

They continue to have the exact same symbol that has `GLOBAL` level binding.

This time, however, we asked the dynamic linker to change how it resolves symbols by specifying the `RTLD_DEEPBIND` flag. From the man pages for `dlopen`:

```
RTLD_DEEPBIND (since glibc 2.3.4)
       Place the lookup scope of the symbols in this shared
       object ahead of the global scope.  This means that a self-
       contained object will use its own symbols in preference to
       global symbols with the same name contained in objects
       that have already been loaded.
```

### Why is the plugin not using common dependency version 2?

While `RTLD_DEEPBIND` can help us in ensuring the linker will give preference to the plugin's symbols ahead of main's in its scope, it can't solve the problem if the library wasn't loaded in the first place. We already previously analyzed the problem in the first attempt (see [Wrong libcommon file gets used in attempt 1](#problem-2---wrong-libcommonso-gets-used)).

If we look at the symbols for `libcommon` in both places:

```console
root@feadq71ea643:/# readelf -W --dyn-sym /usr/local/lib/libplugin_visible_symbols.so | grep common
     2: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _ZN6common16CommonDependency8sayHelloEv
root@feadq71ea643:/# readelf -W --dyn-sym /opt/mains/bin/attempt3 | grep common
     6: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _ZN6common16CommonDependency8sayHelloEv
```

we can see that the exact same symbol is present in both. That does not surprise us one bit since the CommonDependency did not change the interface to its `sayHello` method between version 1 and version 2. If the interface is the same, the symbol must be the same since name mangling is deterministic.

So even though the incorrect library is loaded for the plugin, execution moves forward without problems because the symbol is the same. If the interface had changed, we would find ourselves in front of an ugly crash because the linker wouldn't have found the symbol.
 

## Attempt 4 - use `RTLD_DEEPBIND` with versioned common library

### Configuration Summary
- Main uses `dlopen` with the `RTLD_DEEPBIND` option to somewhat isolate the dynamically loaded library
- Common library added symbolic links and changed the `SONAME` in the ELF file so that users can link to their soversions. Plugin now links to `libcommon.so.2` while main links to `libcommon.so.1`.
- The plugin exports all symbols.

**Involved files**

|File|Description|
|-|-|
|`/opt/mains/bin/attempt4`|Main executable - uses common v1|
|`/usr/local/lib/libplugin_visible_symbols_v.so`|Plugin installation - uses common v2|
|`/opt/common1V/lib/libcommon.so.1`|Common dependency version 1|
|`/opt/common2V/lib/libcommon.so.2`|Common dependency version 2|

#### Code Changes

`common/CMakeLists.txt`

```diff
+   set_target_properties(${PROJECT_NAME}
+            PROPERTIES SOVERSION ${major_version}
+            VERSION ${major_version}.${minor_version}.${patch_version}
+        )
```

`main/main.cpp`

```diff
-   void* library = dlopen("libplugin_visible_symbols.so", RTLD_LAZY | RTLD_DEEPBIND);
+   void* library = dlopen("libplugin_visible_symbols_v.so", RTLD_LAZY | RTLD_DEEPBIND);
```

### Program output
```console
root@feadq71ea643:/# /opt/mains/bin/attempt4
Getting read to load plugin libplugin_visible_symbols_v.so
SoKwel in Plugin says so kwel
I am the common dependency version 2
SoKwel in main says so kwel
I am the common dependency version 1
```

<image src="diagrams/desired_functionality.svg" />

#### It worked! Let's see why

The common dependency team added a `SONAME` and created some symbolic links for the plugin and main team to link to to ensure that different versions of `libcommon` can exist in the same context.

Previously, the common library was built as follows:
```console
root@feadq71ea643:/# ls -l /opt/common1/lib/
total 20
drwxr-xr-x 3 root root  4096 Feb  5 21:06 cmake
-rw-r--r-- 1 root root 15616 Feb  5 21:06 libcommon.so
root@feadq71ea643:/# ls -l /opt/common2/lib/
total 20
drwxr-xr-x 3 root root  4096 Feb  5 21:06 cmake
-rw-r--r-- 1 root root 15616 Feb  5 21:06 libcommon.so
root@feadq71ea643:/# objdump -p /opt/common1/lib/libcommon.so | grep SONAME
  SONAME               libcommon.so
root@feadq71ea643:/# objdump -p /opt/common2/lib/libcommon.so | grep SONAME
  SONAME               libcommon.so
```

So we can see for version 1.0.0, now we have both symbolic links:
```console
root@feadq71ea643:/opt/mains/bin# ls -l /opt/common1V/lib/
total 20
drwxr-xr-x 3 root root  4096 Feb  3 20:54 cmake
lrwxrwxrwx 1 root root    14 Feb  3 20:54 libcommon.so -> libcommon.so.1
lrwxrwxrwx 1 root root    18 Feb  3 20:54 libcommon.so.1 -> libcommon.so.1.0.0
-rw-r--r-- 1 root root 15616 Feb  3 20:54 libcommon.so.1.0.0
```

as well as an addition to the ELF file that will indicate to the static linker the file to link against:

```console
root@feadq71ea643:/# objdump -p /opt/common1V/lib/libcommon.so | grep SONAME
  SONAME               libcommon.so.1
```
The same goes for version 2.0.0:
```console
root@feadq71ea643:/opt/mains/bin# ls -l /opt/common2V/lib/
total 20
drwxr-xr-x 3 root root  4096 Feb  3 20:54 cmake
lrwxrwxrwx 1 root root    14 Feb  3 20:54 libcommon.so -> libcommon.so.2
lrwxrwxrwx 1 root root    18 Feb  3 20:54 libcommon.so.2 -> libcommon.so.2.0.0
-rw-r--r-- 1 root root 15616 Feb  3 20:54 libcommon.so.2.0.0
root@feadq71ea643:/# objdump -p /opt/common2V/lib/libcommon.so | grep SONAME
  SONAME               libcommon.so.2
```

The plugin and main now link against the library indicated by the `SONAME`:

```console
root@feadq71ea643:/# ldd /usr/local/lib/libplugin_visible_symbols_v.so | grep common
	libcommon.so.2 => /opt/common2V/lib/libcommon.so.2 (0x00007ff916370000)
root@feadq71ea643:/# ldd /opt/mains/bin/attempt4 | grep common
	libcommon.so.1 => /opt/common1V/lib/libcommon.so.1 (0x00007f69b914f000)
```

When the program is run, the dynamic linker is happy. `libcommon.so.2` is different from `libcommon.so.1` so it knows it's supposed to load both dependencies.


We can confirm that the `RTLD_DEEPBIND` didn't have the same nasty affect on memory by using `pwndbg`
```console
root@feadq71ea643:/opt/mains/bin# gdb attempt4 

..<SNIP>..

pwndbg> disass main

..<SNIP>..

   0x0000000000002728 <+584>:	lea    rax,[rip+0x2501]        # 0x4c30 <_ZTVSt19_Sp_counted_deleterIPN4kwel19KwelPluginInterfaceEZ4mainEUlS2_E_SaIvELN9__gnu_cxx12_Lock_policyE2EE+16>

..<SNIP>..

pwndbg> b *main+584
Breakpoint 1 at 0x2728
pwndbg> r

..<SNIP>..

pwndbg> vmmap -x
LEGEND: STACK | HEAP | CODE | DATA | RWX | RODATA
             Start                End Perm     Size Offset File
    0x555555556000     0x555555557000 r-xp     1000   2000 /opt/mains/bin/attempt4
    0x7ffff7a42000     0x7ffff7a43000 r-xp     1000   1000 /opt/common2V/lib/libcommon.so.2.0.0
    0x7ffff7a47000     0x7ffff7a48000 r-xp     1000   1000 /usr/local/lib/libplugin_visible_symbols_v.so
    0x7ffff7a5c000     0x7ffff7ad8000 r-xp    7c000   e000 /usr/lib/x86_64-linux-gnu/libm.so.6
    0x7ffff7b5f000     0x7ffff7cf4000 r-xp   195000  28000 /usr/lib/x86_64-linux-gnu/libc.so.6
    0x7ffff7d63000     0x7ffff7d7a000 r-xp    17000   3000 /usr/lib/x86_64-linux-gnu/libgcc_s.so.1
    0x7ffff7e1a000     0x7ffff7f2b000 r-xp   111000  9a000 /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.30
    0x7ffff7fb2000     0x7ffff7fb3000 r-xp     1000   1000 /opt/mains/lib/libso_kwel.so
    0x7ffff7fb7000     0x7ffff7fb8000 r-xp     1000   1000 /opt/common1V/lib/libcommon.so.1.0.0
    0x7ffff7fc1000     0x7ffff7fc3000 r-xp     2000      0 [vdso]
    0x7ffff7fc5000     0x7ffff7fef000 r-xp    2a000   2000 /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
0xffffffffff600000 0xffffffffff601000 r-xp     1000      0 [vsyscall]
pwndbg> 
```

It looks great. No nasty surprises. I guess it is actually time to pack it in. 

### Wait... a new requirement just came in. They want the option to statically link to the plugin in addition to dynamically loading it with `dlopen`. That means `RTLD_DEEPBIND` is out the window as our symbol resolution fixer. 

## Attempt 5 - Hide symbols in plugin

#### If we have to statically link to the plugin, why does the code continue to call `dlopen`?

Rather than rewrite our test code, we can simulate the static linking requirement by removing `RTLD_DEEPBIND`. The order of symbol binding can change with static linking (for instance we would see the plugin's definition of `soKwel` instead of main's if the plugin exports that symbol), but we will get the same end results: either symbols and/or library names clash or they do not. With static linking though, we would get a warning during the build telling us `/usr/bin/ld: warning: libcommon.so.2, needed by /opt/plugin/lib/libplugin.so, may conflict with libcommon.so.1`. Other than those minor differences, for the purposes of this toy application for playing around with symbol and library conflicts, the differences do not matter.

#### For this attempt, we start off hiding symbols

Before we even begin the attempt, we already know that the `_ZN4kwel6SoKwel6soKwelEv` symbol is a problem. Without `RTLD_DEEPBIND` or `dlmopen`, we're back to attempt 1 where we saw the [symbol collision](#problem-1---kwelsokwelsokwel-symbol-collision). So we reason: if the dynamic linker bound that symbol because it had global scope in the dynamic symbols section of the ELF file, then we can solve the problem with just removing it. An easy way to remove it is to hide the symbol. No one from the outside needs to be calling it anyway so it really didn't belong there in the first place.

### Configuration Summary
- Common library added symbolic links so that users can link to their soversions. Plugin now links to `libcommon.so.2` while main links to `libcommon.so.1`.
- The plugin hides all symbols except for the `getPlugin` function that main needs to call.

**Involved files**

|File|Description|
|-|-|
|`/opt/mains/bin/attempt5`|Main executable - uses common v1|
|`/usr/local/lib/libplugin_hidden_symbols_v.so`|Plugin installation - uses common v2|
|`/opt/common1V/lib/libcommon.so.1`|Common dependency version 1|
|`/opt/common2V/lib/libcommon.so.2`|Common dependency version 2|

#### Code Changes

`plugin/CMakeLists.txt`

```diff
+   set(CMAKE_CXX_VISIBILITY_PRESET hidden)
+   set(CMAKE_VISIBILITY_INLINES_HIDDEN YES)
```

Because the `getPlugin` function already had the `__attribute__((visibility("default")))` decorator to export that symbol, no other changes are required.

`main/main.cpp`

```diff
-   void* library = dlopen("libplugin_visible_symbols_v.so", RTLD_LAZY | RTLD_DEEPBIND);
+   void* library = dlopen("libplugin_hidden_symbols_v.so", RTLD_LAZY);
```

### Program output
```console
root@feadq71ea643:/# /opt/mains/bin/attempt5
Getting read to load plugin libplugin_hidden_symbols_v.so
SoKwel in plugin says so kwel
I am the common dependency version 1
SoKwel in main says so kwel
I am the common dependency version 1
```
<image src="diagrams/attempt3.svg" />

### What's happening?

- **Problem:** The common dependency version that main uses gets used also in the plugin.


#### Is the static linking correct and do both `libcommon` libraries get loaded?

Let's first check out the plugin to make sure it links to the versioned `so` link. Also we want to make sure that file gets loaded by the dynamic linker.

```console
root@feadq71ea643:/# ldd /usr/local/lib/libplugin_hidden_symbols_v.so | grep common
	libcommon.so.2 => /opt/common2V/lib/libcommon.so.2 (0x00007fa283bbd000)
root@feadq71ea643:/# LD_DEBUG=libs /opt/mains/bin/attempt5 2>&1 1>/dev/null | grep /opt/common2V/lib/libcommon.so.2
       130:	  trying file=/opt/common2V/lib/libcommon.so.2
       130:	calling init: /opt/common2V/lib/libcommon.so.2
       130:	calling fini: /opt/common2V/lib/libcommon.so.2 [0]
```

Let's do the same for the main

```console
root@feadq71ea643:/opt/mains/bin# ldd attempt5 | grep common
	libcommon.so.1 => /opt/common1V/lib/libcommon.so.1 (0x00007fa505b07000)
root@feadq71ea643:/# LD_DEBUG=libs /opt/mains/bin/attempt5 2>&1 1>/dev/null | grep /opt/common1V/lib/libcommon.so.1
       164:	  trying file=/opt/common1V/lib/libcommon.so.1
       164:	calling init: /opt/common1V/lib/libcommon.so.1
       164:	calling fini: /opt/common1V/lib/libcommon.so.1 [0]
```

Ok, so the files get loaded. Given our previous experience with symbols, let's see what symbol bindings happen:

```console
root@feadq71ea643:/# LD_DEBUG=bindings /opt/mains/bin/attempt5 2>&1 1>/dev/null | grep CommonDependency
       170:	binding file /opt/mains/bin/attempt5 [0] to /opt/common1V/lib/libcommon.so.1 [0]: normal symbol `_ZN6common16CommonDependency8sayHelloEv'
       170:	binding file /usr/local/lib/libplugin_hidden_symbols_v.so [0] to /opt/common1V/lib/libcommon.so.1 [0]: normal symbol `_ZN6common16CommonDependency8sayHelloEv'
```

Yep, we're back with a symbol collision. The `libplugin_hidden_symbols_v.so` should be binding to `/opt/common2V/lib/libcommon.so.2` but it's not.

### Why did hiding symbols fix the SoKwel problem?

If we look at the .dynsym table for this new plugin version:

```console
root@feadq71ea643:/# readelf -W --dyn-syms /usr/local/lib/libplugin_hidden_symbols_v.so 

Symbol table '.dynsym' contains 16 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000000     0 FUNC    WEAK   DEFAULT  UND __cxa_finalize@GLIBC_2.2.5 (2)
     2: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _ZN6common16CommonDependency8sayHelloEv
     3: 0000000000000000     0 OBJECT  GLOBAL DEFAULT  UND _ZTVN10__cxxabiv117__class_type_infoE@CXXABI_1.3 (3)
     4: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __cxa_atexit@GLIBC_2.2.5 (2)
     5: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _ZdlPv@GLIBCXX_3.4 (4)
     6: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _Znwm@GLIBCXX_3.4 (4)
     7: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __stack_chk_fail@GLIBC_2.4 (5)
     8: 0000000000000000     0 OBJECT  GLOBAL DEFAULT  UND _ZTVN10__cxxabiv120__si_class_type_infoE@CXXABI_1.3 (3)
     9: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _ZNSt8ios_base4InitC1Ev@GLIBCXX_3.4 (4)
    10: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND puts@GLIBC_2.2.5 (2)
    11: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_deregisterTMCloneTable
    12: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__
    13: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_registerTMCloneTable
    14: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _ZNSt8ios_base4InitD1Ev@GLIBCXX_3.4 (4)
    15: 0000000000001260    33 FUNC    GLOBAL DEFAULT   14 getPlugin
```

We can see that the problematic symbol, `_ZN4kwel6SoKwel6soKwelEv`, that we identified back in [Attempt 1 looking at the symbol collision](#problem-1---kwelsokwelsokwel-symbol-collision), is no longer present in the table. That means the dynamic linker doesn't have to go through its symbol resolution process like it did before and so no collision occurs. The main has not changed and continues to export the same symbol as a global bind.

## Attempt 6 - Add versions to Common Dependency symbols

### Configuration Summary
- Common library added symbolic links so that users can link to their soversions. Plugin now links to `libcommon.so.2` while main links to `libcommon.so.1`.
- The plugin hides all symbols except for the `getPlugin` function that main needs to call.
- The common library has now added versions to its symbols

**Involved files**

|File|Description|
|-|-|
|`/opt/mains/bin/attempt6`|Main executable - uses common v1|
|`/usr/local/lib/libplugin_hidden_symbols_s_v.so`|Plugin installation - uses common v2|
|`/opt/common1SV/lib/libcommon.so.1`|Common dependency version 1|
|`/opt/common2SV/lib/libcommon.so.2`|Common dependency version 2|

#### Code Changes

`main/main.cpp`

```diff
-   void* library = dlopen("libplugin_hidden_symbols_v.so", RTLD_LAZY);
+   void* library = dlopen("libplugin_hidden_symbols_s_v.so", RTLD_LAZY);
```

#### Build changes

`common library cmake config addition`

```diff
+   -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--default-symver"
```

### Program output
```console
root@feadq71ea643:/# /opt/mains/bin/attempt6
Getting read to load plugin libplugin_hidden_symbols_s_v.so
SoKwel in plugin says so kwel
I am the common dependency version 2
SoKwel in main says so kwel
I am the common dependency version 1
```

<image src="diagrams/desired_functionality.svg" />

#### It worked! Let's see why

```console
root@feadq71ea643:/# ldd /usr/local/lib/libplugin_hidden_symbols_s_v.so | grep common
	libcommon.so.2 => /opt/common2SV/lib/libcommon.so.2 (0x00007f9f2d180000)
root@feadq71ea643:/# readelf -W --dyn-syms /usr/local/lib/libplugin_hidden_symbols_s_v.so  | grep common
     2: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _ZN6common16CommonDependency8sayHelloEv@libcommon.so.2 (3)
root@feadq71ea643:/# readelf -W --dyn-syms /opt/common2SV/lib/libcommon.so.2  | grep common
     6: 0000000000001120    16 FUNC    GLOBAL DEFAULT   15 _ZN6common16CommonDependency8sayHelloEv@@libcommon.so.2
     7: 0000000000000000     0 OBJECT  GLOBAL DEFAULT  ABS libcommon.so.2
```

```console
root@feadq71ea643:/# ldd /opt/mains/bin/attempt6 | grep common
	libcommon.so.1 => /opt/common1SV/lib/libcommon.so.1 (0x00007f7f17a83000)
root@feadq71ea643:/# readelf -W --dyn-sym /opt/mains/bin/attempt6 | grep common
    13: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND _ZN6common16CommonDependency8sayHelloEv@libcommon.so.1 (8)
root@feadq71ea643:/# readelf -W --dyn-sym /opt/common1SV/lib/libcommon.so.1  | grep common
     6: 0000000000001120    16 FUNC    GLOBAL DEFAULT   15 _ZN6common16CommonDependency8sayHelloEv@@libcommon.so.1
     7: 0000000000000000     0 OBJECT  GLOBAL DEFAULT  ABS libcommon.so.1
```

```console
root@feadq71ea643:/# LD_DEBUG=bindings /opt/mains/bin/attempt6 2>&1 1>/dev/null | grep _ZN6common16CommonDependency8sayHelloEv
        64:	binding file /opt/mains/bin/attempt6 [0] to /opt/common1SV/lib/libcommon.so.1 [0]: normal symbol `_ZN6common16CommonDependency8sayHelloEv' [libcommon.so.1]
        64:	binding file /usr/local/lib/libplugin_hidden_symbols_s_v.so [0] to /opt/common2SV/lib/libcommon.so.2 [0]: normal symbol `_ZN6common16CommonDependency8sayHelloEv' [libcommon.so.2]
```

We can see during binding that the linker factors in the symbol versions and bound the `_ZN6common16CommonDependency8sayHelloEv` with version `libcommon.so.1` found in the common version 1 build to main, while it bound the same symbol, `_ZN6common16CommonDependency8sayHelloEv`, but with version `libcommon.so.2` found in the common version 2 build to the plugin. 

We've satisfied all requirements. A word of caution, however. If you have a mix of versioned and not versioned symbols, then you'll potentially have some incorrect bindings since there's not enough information to exclude certain associations.