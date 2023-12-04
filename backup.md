

In 1990, integrating commercial library-level generally required buying a license from its author, and being shipped physical disks-full of two kinds of content: executable binaries, and interface-files telling application code how to call them. The source/ header file split of the C/C++ family was particularly well-paired with this model. While the binary-ness of the primary executable programs is notionally for sake of program-size and ease of installation, it has a material side-benefit: binaries have generally been sufficiently inscrutable to generally evade reverse-engineering and (too much) piracy. Whether for "security" or not, the binary/ header split patterns an abstract vs implementation separation. Integrators of such libraries work against abstract versions (the headers), without needing details of their implementation (the binaries).



---





The past decade's work at Berkeley (as well as many peer institutions) has included a renewed commitment to the _design productivity_ of IC designers. In addition to producing advances in computer architecture and circuit design, research programs have included substantial software development efforts towards making chips easier to design and build, with substantially less design effort, in a wider variety of semiconductor process technologies. 

A central facet of this work has been the emphasis on _hardware generators_ The generator concept (while perhaps under-defined) 

### Software

Over those 30 years, two changes in software-sharing stand out as most impactful: the open-source movement, and the emergence of the SaaS model overhauling how most commercial software is distributed.

In 1990, integrating commercial library-level generally required buying a license from its author, and being shipped physical disks-full of two kinds of content: executable binaries, and interface-files telling application code how to call them. The source/ header file split of the C/C++ family was particularly well-paired with this model. While the binary-ness of the primary executable programs is notionally for sake of program-size and ease of installation, it has a material side-benefit: binaries have generally been sufficiently inscrutable to generally evade reverse-engineering and (too much) piracy. Whether for "security" or not, the binary/ header split patterns an abstract vs implementation separation. Integrators of such libraries work against abstract versions (the headers), without needing details of their implementation (the binaries).

Later the internet enabled the "as a service" software-sharing model, in which library-level code is not distributed as a binary, but as network-based API calls to a library-author-managed server. Distribution as-a-service added benefits in its ease-of-update, both to its author and to its users. Binary distribution still pervades high-performance environments, such as the physics engines which power advanced 3D games.

Software distribution and development have also been overhauled by the emergence of open-source development. Open-source software is prevalent at all levels of the software-stack, but particularly for library-level building blocks: languages, compilers, runtimes, frameworks, and the like. Sharing and designing open-source software have essentially merged into a single activity, facilitated by public hubs such as GitHub. The integration of git's popular revision-control and development meta-material such as bug-tracking, access control, testing, and documentation publication have made these hubs functional one-stop shops for the development of these projects.

While GitHub has become the face of open-source software _development_, it is almost certainly not where or how most open-source software is shared to be _used_. Instead each coherent community, commonly either a programming language or operating system, generally defines a package manager abstraction. These managers generally comprise two parts: (a) a database of published, versioned, documented designs, and (b) a suite of user-tools co-designed with their package-format, which comprehends how to incorporate, compile, or integrate modules from the database. The combination enables reuse among users with faint awareness of the combined system at work, e.g. via simple installation or compilation commands such as "pip install numpy".

### Integrated Circuits

The integrated circuit (IC) space essentially cleaves in two camps: digital circuits, which benefit from several software-like factors, and analog/custom circuits (including memory), which generally do not.

Digital IC design has primarily lived in C-ish-level hardware-description languages since their advent in the 1980s. Popular digital HDLs are then commonly "compiled" (although often not called this) to one of two targets: simulation-targeted binary executables, and implementation process technologies. The two most prominent HDLs, (System)Verilog and VHDL, are both open IEEE standards. HDL code written in these languages is (in principle) technology-portable. Designs using either language are (again, in principle) shareable as open-source software. Increasingly many are shared through public hubs such as GitHub, although usage of these in larger systems remains harder to gauge, and likely highly limited.

The HDL "simulation compiler" transforms an HDL "program" into a binary executable on an evaluation machine, often the same machine on which it is being designed. These logic-level simulations are often used for much (or most) of a digital-IC design process, until it needs to be mapped into a target technology.

The latter "implementation compiler" targets a realizable chip-blueprint, or "layout". This compilation commonly occurs in two steps: logic synthesis first transforms a "hardware program" into a set of logic-gate-level primitives available in the target technology. Most commonly these primitives are either (a) standard logic cells in ASIC targets, or (b) LUTs in FPGA targets. The second stage, "place and route" (PnR), maps these gates into a physical layout, choosing locations for each and geometries for wiring between them. PnR is generally iterative: it guesses a candidate layout, evaluates one or more quality metrics, and updates that layout based on its observed quality. Closure is reached in fixed-point style, when iterations cease to produce material changes. The original circuit is often modified inline by these programs, changing their relative drive strengths, splitting or combining logic gates, and/or inserting and removing logically equivalent networks, i.e. by inserting logic buffers. Much as the binary output of a C compiler is generally unrecognizable to its C-language author, the gate-level netlists produced by auto-PnR are generally unrecognizable by their HDL authors. Complex state machines are (necessarily) broken into individual bit-level gates, and (frequently) heavily rearranged to reduce area or power.

These synthesized layouts are commonly optimized for one or more of (a) total wire length, which is often found proportional to delay and power consumption, (b) closure of timing constraints (in "timing driven" optimizers), or (c) power consumption itself. Two important delineations enable a layout optimizer to make thousands of layout-iterations and evaluations of these metrics:

- First is the separation between behavior and timing. Layout-compilation programs do not, for example, evaluate whether a design continues to correctly execute its target instruction-set between iterations. This is instead broken in two verification steps. First, logical simulation determines whether a candidate design behaves as intended, assuming synchronous timing constraints are met. Static timing analysis then determines whether those constraints are in fact met. Transformations made during layout synthesis maintain this behavior by ensuring that the network's logical function is unchanged; only timing is modified.
- Second, while evaluation of static timing closure is itself costly, it has several quickly evaluatable surrogates. Total wirelength (for all nets) has long served as a primary in-situ metric for layout compilation.

Several classes of digital circuits are also amenable to "high-level" synthesis, generally from procedural programs. These programs typically accept a C or C++ program, which may or may not be multi-threaded, as input, and produce as output an RTL-level circuit which efficiently "executes" the input program. This allows for designers to operate in the typically more human-intuitive procedural mode, while allowing the compiler to produce inherently parallel-executing hardware. HLS has been most successful for circuits with highly regular data-paths, such as those for digital signal processing. Circuits more-prominently dominated by control logic have proven less amenable.

### Analog \& Custom IC Content

Analog and custom circuits (hereon referred to as "analog", but notably including very-digital custom things such as SRAM and IOs) have escaped nearly all these productivity-enhancing pieces of software. These circuits often have performance metrics or design methods which evade the technology-portable hardware-description concepts. They are typically designed in and for a specific implementation technology. Automated design and layout of these circuits has long been an academic pursuit, but one with little industrial adoption. Notably these circuits escape the behavior/ timing layout-quality-evaluation dichotomy. Checking whether the layout of, say, a comparator, meets a set of specifications amounts to fully evaluating whether the circuit behaves as a comparator. These evaluation times are further (greatly) exacerbated in modern technologies by the injection of layout-parasitic circuit elements, which for accurate evaluation often outnumber intentional circuit elements by orders of magnitude. Iterative layout is therefore rendered order of magnitude slower than for digital circuits, which itself can often incur runtimes of several days.

### Sharing of IC Content via "Silicon IP"

The sharing of IC-level circuits is materially affected by several practical considerations. Both the underlying implementation technologies and commercial software tools are strenuously guarded by their owners. Access to even trailing-edge (much less leading-edge) IC technology requires substantial legal and commercial agreement, and has increasingly become the target of international public policy. These agreements are generally designed per institution. Sharing design-data using Foundry-X between (design) Company-A and Company-B generally requires the permission of Foundry-X. Accordingly only the largest institutions with sufficient commercial benefit or scale to amortize these agreements participate. Commercial EDA software, such as that used for layout PnR or simulation, uses a similar per-institution licensing model, generally limited to the institution's on-premise physical machines. These EDA programs are also prohibitively costly for all but the largest institutions to license, often totaling in millions of USD per designer-year.

Despite these constraints. commercial "sharing" of these IC-level circuits is a common practice, typically known as silicon IP. "IP" is a term of art in the silicon space. In context it means something fairly different from in the rest of the world. Silicon "IPs" might be more descriptively called "virtual sub-chips": they consist of the design-files for IC sub-circuits. These IP-blocks can be distributed at several levels of detail (e.g. "soft" HDL code, vs "hardened" physical layout). Probably the most successful company in silicon-IP's history has been ARM, the designer-licensor of the overwhelming majority of the world's embedded processors. While one commonly refers to these devices as containing "ARM chips", even industry-insiders often forget that ARM does not make chips at all. They make virtual sub-chips, licensed by and integrated into the chips of a wide range of IC companies.





### System-Level Hardware

System-level circuits have unique constraints, but among the previously examined cases, look most like analog IC design. Designers typically "program" their hardware in graphical schematics, comprised of symbolic physical components and connections there-between. Simulation plays a much smaller role than for IC-level circuits. Automatic design and/or layout generation is essentially nonexistent, largely attributable to the lack of reusable, quickly evaluatable quality metrics.

Sharing of PCB circuits is aided by their implementation technology: PCBs and discrete physical components. Unlike silicon process technologies and silicon IP, the required information to integrate discrete components is generally publicly available. These "component abstracts" commonly include physical footprints and specification documents. (Automatic interpretation of these documents is of course much more limited.) Publicly-available components generally have publicly-available such information.

Sharing of these component-descriptions has however remained largely ad-hoc. While millions of such part-descriptions are shared on several public distribution hubs such as DigiKey, designs using them commonly self-vendor design-files and relevant information for their integration. At large (and even small) hardware companies, integration into enterprise-level software databases, e.g. those for inventory and sales projections, are as important as their technical content. These substantial databases therefore remain siloed within each institution.

PCBs are also widely available without substantial overhead (e.g. NDA agreements with a PCB fab). Their z-axis cross-section, commonly called a stack-up, is highly customizable by most fabs and for most boards.

PCB circuit-level sharing is far less common. While PCB-level circuits are (in principle) "virtual sub-PCBs" in the same sense that silicon IPs are "virtual sub-chips", nothing resembling the silicon IP ecosystem has emerged at this layer of the stack. Silicon's primary "IP-ization" technologies are those which abstract an underlying circuit, allowing an integrator to make use of an abstract representation without internalizing the details of its implementation. For such abstract descriptions to be sufficiently comprehensive, they typically must include more than one view of the underlying design. Logical and physical views are common examples for silicon IP, which generally map to schematics and layouts on PCBs.

Re-use of PCB layout is often hindered by the very flexibility of their implementation technology: the z-axis stack-ups of PCBs, and the varying capacities of PCB fabs and PCBA assemblers. Analogizing to the silicon space, PCBs have a functionally infinite number of "process technologies".





### General State of Berkeley Chip-Making

The past decade's work at Berkeley (as well as many peer institutions) has included a renewed commitment to the _design productivity_ of IC designers. In addition to producing advances in computer architecture and circuit design, research programs have included substantial software development efforts towards making chips easier to design and build, with substantially less design effort, in a wider variety of semiconductor process technologies. Substantial research-products in this area have included the Chisel digital HDL, Hammer digital back-end framework, ChipYard integration framework, and BAG analog-circuit generation framework.

Digital- and analog-domain efforts in these areas have nonetheless remained relatively silo'ed. Berkeley researchers have produced a number of integrated mixed-signal chips (examples?), but find this point of integration has escaped the program of design-productivity gains. Despite substantial gains in both the digital and analog silos, the connective tissue between the two remains as difficult as ever. Recent research tape-outs have more commonly retreated to one silo or the other: purely-digital machine learning accelerators and CPU architectures in one camp, and purely analog PLLs, transceivers, and biomedical ICs in the other. Many of these chips suffer directly and materially from the lack of the alternate discipline. For example, architecture chips lack any substantial off-chip bandwidth due to the lack of high-speed PHYs, while analog chips have fallen into common pitfalls of digital design in custom methodology (missing timing paths, behavioral inconsistencies, etc.)

### The Modern Berkeley Digital Flow

UCB's digital IC and computer architecture research is primarily performed in home-grown front-end and back-end frameworks. The Chisel HDL, embedded in the Scala programming language, adds a rich set of parametric RTL-generator facilities above industry-standard tools such as SystemVerilog. Back-end design primarily uses the Hammer framework, based in Python, for configuration of process technologies and back-end EDA tools. The overarching ChipYard framework largely serves to integrate the two, while also enabling several other home-grown design-productivity tools, such as cloud-FPGA-accelerated simulation via FireSim. Researchers in these areas have seen substantial productivity gains from this suite of tooling, often creating large-scale research chips with small teams on limited schedule.

### Berkeley's Analog Generator Framework, BAG

Analog design lacks the clear separating between front- and back-ends that the digital paradigm afford. Berkeley flows are a central example - the principal front- and back-end frameworks (Chisel and Hammer, respectively) can be used together, or either can be paired with external, third-party, or industry standard tools.

Berkeley's analog design generation framework (BAG), in contrast, includes both the "front" and "back" ends of analog designs (to the extent these exist), as well as facilities for creating test benches, running SPICE-class simulations, processing simulation data, and generating digital-targeted abstract views, typically in the form of LEF and Liberty-format files.

This begs an aside on the use of the term "generator", for use in any of these contexts. "Generators" have become an umbrella term of sorts at Berkeley, generally associated with somehow using modern programming practices to generate IC hardware content. More specific associations differ quite widely between the analog and digital "generator frameworks". Chisel's digital generators might be thought of as Scala programs whose output is synthesizable RTL, represented either in SystemVerilog or FIR-RTL. Typical parameter-spaces include the width of buses and instance arrays, modal controls enabling or disabling RTL features, and similar. Generator inputs for the Gemmini ML accelerator illustrate an example case:

(code example)

BAG's analog generators, in contrast, attempt to codify a design process in a near-arbitrary process technology. These programs tend to look a bit more like constrained optimizers. Typicaly inputs include a set of target performance specifications (e.g. gain, noise, resolution), and a representation of the target process technology. Often reaching design-closure requires launching and analyzing dozens or hundreds of simulations, requiring run-times of hours or days. Just as often, a given combination of generator-code, target-specs, and constraints is unable to converge on a solution. Often the high-level _behavior_ (and/ or IO interface) of the generated analog circuit is a strong function of its technology and constraints.

Point being: _generators_ mean fairly different things to these different audiences. Inline integration of the two is possible in principal, by running BAG generators with inputs provided from parent Chisel generators during RTL elaboration. But their differences in use-case and run-time favor a model in which BAG's generators are run "offline", and incorporated into digital design in the more conventional fashion of "hard IP".

Whether run "inline" or "offline", each parent block must have reasonable assurance that it knows its sub-block interfaces, for any set of parameters it may provide. Addition or removal of ports based on input parameters serves as a common example of where this assurance is broken. Including physical design (e.g. outline, pin placement, layers and blockages) dramatically expands the scope of these potential errors.

### BAG Layout Generation

A central facet of the BAG framework is its ability to generate semi-custom process-portable layout. High priority is placed on the portability of an analog circuit from one technology to another. Less emphasis is placed on physical integration into any particular digital design flow. This portability is in part achieved by placing layout elements on a "base grid", analogous (although aways more flexible than) standard-cell or gate-array style CMOS placement. Each process technology is represented by a Python package, largely configured through a set of paired YAML configuration. Overall, layout styles are dictated by two primary layers of such configuration:

- (a) Technology-specific configuration, which set the allowable line widths, spacings, and device sizes
- (b) Per-generator configuration, which set what the BAG community call its "floorpan" (which standard cell library designers would more commonly call a "template" or "layout style")

(Maybe include an example)

The technology-specific configuration of (a) is particularly brittle for sake of digital integration. Digital back-end design, such as done via Hammer, dictates an analogous set of process-specific and design-specific wiring rules, of which BAG is unaware. Reconciling the two requires one of:

- (Very) good fortune that the two align, or
- Concession by the digital back-end to adopt the BAG template, or
- Re-design of the BAG process-technology package, or
- A "reconciliation area" surrounding the analog circuit, converting between its and the digital layout's metal grid. By definition, design of this area must be done in the digital back-end flow, where custom metal placement is often even more taxing than in semi-custom layout.

### Abstracts as Contracts

A central facet of any modern, high-complexity IC design flow is the capacity to design _hierarchically_. Sub-chips are broken into conceptual units ("modules" or "subcircuits") which the remainder of the system can comprehend without a complete implementation, via _abstract views_. These sub-chips commonly include one (or more) abstract view per discipline, including:

- _Layout abstracts_, most commonly in LEF format, summarize layout implementations (commonly GDS or OA)
- _Timing abstracts_, most commonly in Liberty format, summarize an broad set of timing-related behaviors, including the inclusion of logic paths, interface timing constraints, drive strengths, and input loads. In principal these stand in for hundreds of time-consuming simulations.

Note that while particular file-formats may be required by particular design tools (e.g. place and route, STA), the conceptual content can appear in any format.

These "summarization" facilities of the abstract-formats are commonly used after designs are complete. Most layout-generation software (such as BAG) will output a "summarizing" LEF-file given a complete layout implementation. Static timing analyzers similarly "summarize" their results into Liberty format. While the summarization-mode is _necessary_ for large and complex IC designs, it can by definition only be of use once a candidate design is complete. This offers little to the design process leading to its generation, or the ability for sub-chip designers to define inter-block interfaces and confidently execute against them.

Introduce _abstract as contract_. In this model, interfaces between sub-chips (for example, analog vs digital) are defined by these abstract design-views. These definitions occur (very) early in the design process, and consititute the _contract_ between blocks. Design on either side of this contract-interface then amounts in some sense to filling in detail which _implements_ this abstract-contract. Determination of success or failure amounts to a comparative check of whether a design implements the contract.

Take an analogy (which will particularly land for analog designers) - the parametric specification table. We'll imagine an amplifier embedded in an analog signal chain, of sufficient complexity to have different top-level and amplifier-level designers. The parametric specifications provided to the amplifier designer might look something like so:

| Spec                          | Min  | Max  | Unit |
| ----------------------------- | ---- | ---- | ---- |
| 3dB Bandwidth                 | 100  | -    | MHz  |
| Input Common-Mode Voltage     | 0.4  | 0.6  | V    |
| Power Consumption             | -    | 500  | µW   |
| Input-Referred Offset Voltage |      | 5    | mV   |

This is the common form of an analog-designer's work-statement: given a qualitative description of a circuit's behavior and a quantitative set of spec-requirements, produce a realizable design (schematics, layout drawings, and the like) which adhere to the specs. The spec-table is the _performance abstract_ in this sense; the signal-chain designer need not refer to each detailed simulation, but instead relies on their adherence to the (vastly simplified) spec-table. It serves as the contract between layers, against which the signal-chain designer can perform his own calculations and go about his own design process.

Now to complete our analogy: imagine that after months of detailed work, a subtle realization causes the designers to realize that the amplifier's offset is, say, 3.5mV instead of 4mV. (This might be from a device-model change, a misplaced simulation setting, or any other external factor.) What happens? Generally _just about nothing_. Both values of offset adhere to the contract. The top-level designer need not re-analyze, re-simulate, or re-plan for the new values, so long as his past analysis assumes the contracted performance (and no more).

Industry-standard practice (and common sense) dictates that designers do this all the time. We erect relatively abstract fences, and allow each neighbor to work on her own side of them. Physical and timing design have largely escaped this bit of common sense. Were the change instead to, for instance, the input capacitance of a pin in a Liberty timing abstract, common practice would be to re-generate these summaries at every involved level of hierarchy, and re-do any associated analysis. The physical and timing analyses tend to base themselves on implementations rather than their abstract-contracts. In an even more common case for custom physical design, unintended changes to layout implementation often bubble up through LEF "summaries", disrupting neighboring blocks.

The _abstract as contract_ methodology requires two essential components for each design-view:

- (a) Efficient _abstract generation_, to create the contract-views before having detailed design in hand
- (b) _Implementation versus abstract comparison_, for determining whether a design implementation adheres to its contract

Many tools have been written to aid in (a), at least when targeted at a particular discipline. None have either reached industry-standard common usage, or targeted producing the abstracts for _several_ disciplines (e.g. timing plus physical plus behavioral). Instead designers commonly deploy one-off scripting and programming to generate the target abstract-file-formats. This is furthered by their common text-based representations, particularly for LEF and Liberty. This text-basedness also furthers the ad-hoc comprehension of the formats. Each is typically represented by a substantial PDF-based manual and small set of examples. Rarely will generation programs comprehend the entirety of these formats, or have facilities for checking their compatibility with any other implementation of the standards.

Any existing tools for facet (b), comparison, remain unknown to the author. Automated _abstract as contract_ methodology would require authoring such comparison programs, initially for the physical and timing disciplines. Both would appear to be tractable and valuable contributions to the field. As noted in our prior example, parametric-abstract comparison essentially happens all the time, in the form of simulation measurements and their comparisons against target metrics. (Automation of these tasks can of course improve.) Behavioral _contracts_ might take on a number of forms, including (a) vectored simulation, exercising each system-desired behavior, and/or (b) formal-verification methods.

