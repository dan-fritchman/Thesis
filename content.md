
# Some kinda intro to the whole problem

* This is about integrated circuits
* Particularly the analog parts
* The whole conceptual layer-cake on which they get designed

Integrated circuits are "integrated" in the sense that more than one - and often in current practice, more than ten orders of magnitude more than one - circuit component is integrated in a single silicon die. 

The most detailed representation of these circuits, and the sole representation sufficiently detailed for fabrication, is commonly called _layout_. IC layout is a chip's physical blueprint. The nature of silicon manufacturing allows for representing these blueprints in "2.5D" terms. Each silicon wafer is extremely uniform in one of its three axes. This axis extends into and out of the plane of the die surface, and is commonly referred to as the z-axis. This z-axis is typically split into a discrete number of _layers_. These layers refer to a variety of physical features, such as metal connections, insulators there-between, ion injections which form transistor junctions, etc. The IC "x" and "y" dimensions, in constast, span the surface of the die, and are much more free-form to be specified by the IC designer. These two axes typically allow for nearly free-form closed 2D polygons. An IC blueprint is therefore comprised of a list of such polygons, each affixed with a z-axis layer annotation. 

While layout is the sole language comprehensible for IC fabrication, it is generally far too detailed for much of IC design. The silicon design and closely related electronic design automation (EDA) fields have, over time, produced a substantial stack of software, concepts, and practices which allow for IC-design at far more abstract levels than that of physical layout. Different subsets of the IC field have proven more and less amenable to these things.

* Something about how verification works, ie. logic sim vs spice
* Netlists/ schematics as the "assembly"
* RTL/ HDL code as the "C"
* Whatever we wanna say about "high level" stuff
* Table of that stuff

\begin{center}
\begin{tabular}{|c|c|}
 IC Layer & Analogy \\ 
 RTL & C  \\  
 Netlist & Assembly \\    
 Layout & Machine \\    
\end{tabular}
\end{center}

One of two paradigms produce essentially all modern IC "blueprints". These two models .... 

In the first model, commonly paired with digital circuits, an optimizing "layout compiler" produces an ultimate blueprint from a combination of an RTL-level circuit design and a set of physical constraints and/or goals. These two designer-inputs are fed to a compilation pipeline, generally comprising a combination of logic synthesis which translates RTL to gate-level netlists, and "place and route" (PnR) layout compilation. We refer to this paradigm as "the digital model" or "the compiled model". 

In the second model, there is no compiler. The designer directly dictates the IC's physical blueprint, generally through graphical means. This approach is generally paired with analog circuits, for which many of the successful methods used in digital layout compilers tend to break down. We refer to this paradigm as "the analog model" or "the custom model". 


Analog and custom circuits such as memory have long been acknowledged as a bottleneck in the IC design process. In the author's anecdotal experience, analog efforts tend to produce transistor-counts per effort (e.g. designer-months) on the order of 100-1000x lower than their digital peers.

Several recent research efforts including ALIGN [@kunal2019align], MAGICAL [@chen2020magical], and BAG [@chang2018bag2] have taken a variety of approaches to improve the state of the field. These and similar research efforts can be grouped into two large categories: 

* 1. _Constraint-based_ systems, which expose an API or language for setting constraints and/ or goals for a _layout solver_. In essence these systems map the digital layout-compilation pipeline onto analog circuits. 
* 2. _Programmed custom_ systems, notably including BAG, which instead expose an elaborate API to directly manipulate _layout content_. The essence of such systems is to replace the conventionally graphical interations - adding a polygon to a layout, setting a parameter, invoking a simulation - with API calls. 

None of these projects nor their underlying methods have broken through to widespread adoption. 

# IC Design Databases

IC design data is commonly represented in "design databases". These formats and their access software generally look much like the low layers of a relational database management system (RDMS). They include a binary format for storing and packing records, and a API for querying and writing those records. Their central goal is to enable efficient offloading between memory and disk, especially for designs too large to reasonably fit in memory. This goal is near entirely driven by one application: digital PnR layout compilation. For common digital circuits including millions of gates and associated metadata, the optimization makes sense. Optimal PnR, and even "good enough" PnR, remains an NP-complete problem which commonly requires industrial-scale resources and days of runtime. Without such optimizations, large compilations often fail to complete. 

Analog circuits differ in several respects. First and perhaps most importantly: they are much smaller. Rarely if ever 

Second, analog circuits demand to be designed and laid out hierarchically for another reason: their verification is hierarchical. Their necessary mode of evaluation - the SPICE-class simulation - is far too slow, and scales far too poorly, to evaluate compound circuits in useful runtimes. Compound analog circuits such as RF transceivers, wireline SERDES transceivers, data converters, and PLLs are commonly comprised of subsystems whose simulation-based verification is far more tractable than that of the complete system. 

## Protocol Buffers

```protobuf
message Person {
   optional string name = 1;
   optional int32 id = 2;
   optional string email = 3;
}
```



## The VLSIR Design Database Schema


[VLSIR's core design database](https://github.com/vlsir/vlsir) is defined in the open-source [Protocol Buffers](https://github.com/protocolbuffers/protobuf) schema description language (SDL). Protocol Buffers were originally designed as an efficient binary data format for exchange between programs running in isolated, often mutually-incompatible container environments. Given a data schema, an associated compiler generates interface code in a variety of popular programming languages. A simplified excerpt from the VLSIR schema, defining the `layout.Instance` type, is included below. 


```protobuf
// # Layout Instance
message Instance {
  string name = 1;     // Instance Name
  Ref cell = 3;        // Cell Reference
  
  Point origin = 4;    // Origin location 
  bool reflect = 6;    // Reflection 
  int32 rotation = 7;  // Rotation (deg)
}
```

The VLSIR schema defines such types for circuits, layout, spice-class simulation input and output, and process technology. 
The schema format serves as a core exchange medium for a variety of programs and libraries written in a variety of languages, with varying trade-offs between designer productivity and performance. 

# The Analog Religion's Sacred Cow

The primary high-productivity interface to producing VLSIR circuits and simulations is the [Hdl21](https://github.com/dan-fritchman/Hdl21) hardware description library. Hdl21's central goal is enabling "circuit programming" by circuit designers with little programming experience. Hdl21 exposes the field's most familiar core concepts  - instances of circuit elements, modular combinations thereof, signals and ports, simulations and their results - as Python objects. The core circuit-reuse element `hdl21.Module`, analogous to the Verilog `module` or Spice `subckt`, is typically defined through a class-body full of element declarations. 

```python
@h.module
class MyModule:
   """"# An example Module """
   i = h.Input()
   o = h.Output(width=8)
   s = h.Signal()
   a = AnotherModule(a=i, b=s, c=o)
```

Hdl21 *generators* are functions which return modules. 

```python
@h.generator
def MyGen(params: MyParams) -> h.Module:
   """"# An example generator """
   m = h.Module()
   m.i = h.Input(width=params.w)
   if params.has_reset:
       m.reset = h.Input()
   return m
```

While Hdl21 includes features for common analog circuit use-cases such as differential pairs, arrays of instances, process technologies, and PVT corners, these two concepts - the module as a data structure, and generators as functions which create them - are sufficient for designers to produce powerful, parametric hardware. 

# Web-Native Schematics 


Hdl21 is largely designed to replace graphical schematics. A central thesis is that most schematics would be better as code. We nonetheless find for a small subset of schematics - the ones containing elements that any designer would recognize - the pictorial schematic remains the most intuitive mode. Hdl21 includes a [paired schematic system](https://github.com/vlsir/Hdl21Schematics) in which each schematic is both a web-native SVG image and is directly executable as an Hdl21 Python generator. 

Each Hdl21 schematic is accordingly a single SVG file, requiring no external dependencies to be read. Linking with implementation technologies occur in code, upon execution of the schematic as an Hdl21 generator. Hdl21 schematics capitalize on the extension capabilities of Hdl21's embedded language, Python, which include custom expansion of its module-importing mechanisms, to include schematics solely with the language's built-in `import` keyword. 

![dvbe](fig/dvbe.jpg "Example SVG Schematic")

# Programming Models for IC Layout

What makes digital circuits so amenable to layout compilation, and analog circuits so poor? 

synchronous
static timing 
easily computable surrogates therefore, such as wirelength

in this sense the anaogy between the digital layout pipeline and the tupical programming language compiler breaks down. Digital pnr does nore than compile a hardware circuit, and does more than thr good faith optimization attrmpts allowed by most optimizing compilers. instead it wraps this compilation in an optimization layer, in which tje optimization objectives (a) are met by design, or the process is deemed jnsuccessful, and (b) are user programmable. the most common and prominent example such metric is the shnchronous clock frwquency. pnr users comminly secify such a frwquenxy or peiord as their sole input constraint. the process is analogous to a c compiler with user inputs dictating its maximum instruction count or memory usage in executing its main program. while such efforts may exist in research or in specialty contexts, they are not the primary use model for popular compolers such as gcc or LLVM/ clang. the term "optikizing compiler" is commonly used to describe these projexts; it would more accurately be applied to digital PnR, in which compilation is wrapped in an optikizing layer rich with goals and constraints. 

analog circuits lack the generalizavle criteria dornsuccess or failure afforded by static timing analysis. each analogncircuit typically 


## the two most tried and failed models


# Programmed-Custom Layout 


Code-based "programming" of (digital) circuits has been commonplace since the introduction of the still-popular hardware description languages in the 1980s. Successful programming models for semi-custom layout have proven more elusive. Most research efforts can be grouped into two large categories: 

* 1. _Constraint-based_ systems, which expose an API or language for setting constraints and/ or goals for a _layout solver_.
* 2. _Programmed custom_ systems, notably including BAG, which instead expose an elaborate API to directly manipulate _layout content_.

While we believe VLSIR's modular design enables both approaches, its applications to date have focused on approach (2). Like the overall framework, layout programming with VLSIR is both modular and layered. The lowest-abstraction, most-detailed layout-programming layer directly manipulates geometric objects and hierarchical instances thereof. This "raw" layer is the basis of open-source generators for SRAM and FPGAs. 

A more abstract "tetris" layer operates on rectilinear blocks in regular grid. Placement is performed through a relative-locations API, while routing is performed through the assignment of circuit nets to intersections between routing tracks on adjacent layers. Underlying "tetris blocks" are designed through conventional graphical means, similar to the design process commonly depolyed for digital standard cells. In a co-designed circuit style, all unit MOS devices are of a single geometry. Parameterization consists of two integer parameters: (a) the number of unit devices stacked in series, and (b) the number of such stacks arrayed in parallel. The core stacked-MOS cells are physically designed similar to digital standard cells, including both the active device stack and a complementary dummy device. This enables placement alongside and directly adjacent to core logic cells, and makes each analog layout amenable to PnR-style automation. 

![mos_stack](fig/pmos_stack.jpg "MOS Stack Design in Standard Logic Cell Style")

# Compiled Layout 

tbd 

# the ml part

tbd 

# Applications

tbd 

# H1 creates a chapter

this one is here at the end for examples of all the content types

## H2 creates a section

Include a figure with a caption: 

![homer](fig/homer.png "Homer's Reaction")

Refer to that figure:

Figure~\ref{fig:homer} shows (blah blah blah).  

## Another Sub-Section

* Bullet
* List
* Without insane Latex nerdery

A horizontal bar (not that we make those):  

---

Code:

```verilog
module WHY #( /* ... */ ); 
  generate
  for (k=0; k<WIDTH; k=k+1) begin
    fa i_fa( /* ... */ );
  end
  endgenerate 
endmodule
```

Citations: 

* Latex [@latexcompanion]
* BAG [@chang2018bag2]
* MAGICAL [@chen2020magical]
* ALIGN [@kunal2019align]


Inline code: `print("...")`  

Link: [overleaf.com](https://www.overleaf.com)  


# A bunch of table examples 

## Since we really dunno Latex

Tables, sadly, must be specified in Latex and not Markdown. 

\begin{center}
\begin{tabular}{ c c c }
 cell1 & cell2 & cell3 \\ 
 cell4 & cell5 & cell6 \\  
 cell7 & cell8 & cell9    
\end{tabular}
\end{center}


\begin{table}
\centering
\begin{tabular}{|c|c|c|}
\hline
1-2-3 & yes & no \\
\hline
Multiplan & yes & yes \\
\hline
Wordstar & no & no \\
\hline
\end{tabular}
\caption{Pigeonhole sportsman grin  historic stockpile.}
\end{table}


\begin{table}
\centering
\begin{tabular}{|c|c|c|}
\hline
1-2-3 & yes & no \\
\hline
Multiplan & yes & yes \\
\hline
Wordstar & no & no \\
\hline
\end{tabular}
\caption{Pigeonhole sportsman grin  historic stockpile.}
\end{table}
Davidson witting and grammatic.  Hoofmark and Avogadro ionosphere.
Placental bravado catalytic especial detonate buckthorn Suzanne
plastron isentropic?  Glory characteristic.  Denature?  Pigeonhole
sportsman grin historic stockpile. Doctrinaire marginalia and art.
Sony tomography.

\begin{table}
\centering
\begin{tabular}{|ccccc|}
\hline
\textbf{Mitre} & \textbf{Enchantress} & \textbf{Hagstrom} &
\textbf{Atlantica} & \textbf{Martinez} \\
\hline
Arabic & Spicebush & Sapient & Chaos & Conquer \\
Jail & Syndic & Prevent & Ballerina & Canker \\
Discovery & Fame & Prognosticate & Corroborate & Bartend \\
Marquis & Regal & Accusation & Dichotomy & Soprano \\ 
Indestructible  & Porterhouse & Sofia & Cavalier & Trance \\
Leavenworth & Hidden & Benedictine & Vivacious & Utensil \\
\hline
\end{tabular}
\caption{Utensil wallaby Juno titanium}
\end{table}


\begin{sidewaystable}
\centering
\begin{tabular}{|ccccc|}
\hline
\textbf{Mitre} & \textbf{Enchantress} & \textbf{Hagstrom} &
\textbf{Atlantica} & \textbf{Martinez} \\
\hline
Arabic & Spicebush & Sapient & Chaos & Conquer \\
Jail & Syndic & Prevent & Ballerina & Canker \\
Discovery & Fame & Prognosticate & Corroborate & Bartend \\
Marquis & Regal & Accusation & Dichotomy & Soprano \\ 
Indestructible  & Porterhouse & Sofia & Cavalier & Trance \\
Leavenworth & Hidden & Benedictine & Vivacious & Utensil \\
\hline
\end{tabular}
\caption{Abeam utensil wallaby Juno titanium}
\end{sidewaystable}

