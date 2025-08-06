# Juliagebra

Geogebra like 3D interactive plotting libary written in Julia and OpenGL.

## Used Packages

Every package used by Juliagebra and the usage examples can be found in the [pkg_installer.jl](pkg_installer.jl) file.

## Examples

Scripts which showcase the use of the library can be found inside [Tests/Examples/](Tests/Examples/).

## Creating dependents

For how a Non-Rendered/Rendered Dependent can be created, a good place to start is [intersections.jl](Prototype/source/Dependents/intersections.jl) and [point.jl](Prototype/source/Dependents/point.jl).

Highly suggested steps for creating a Dependent:
1. Create a file for it in the [source/Dependents/](Prototype/source/Dependents/) folder.
2. Include the created file in [juliagebra.jl](Prototype/juliagebra.jl) below the **Dependents** section.
3. Additional helper files should go in the [source/Helpers/](Prototype/source/Helpers/) folder.
4. Helper files can be included in [juliagebra.jl](Prototype/juliagebra.jl) below the **Helpers** section, or dierctly above the dependent's include, if nothing else uses it.
5. Create a **Plan**.
6. Create a **Dependent**.
7. If needed create a **Renderer**.
8. Once done, create a User accessible (exported) constructor function in [constructors.jl](Prototype/source/constructors.jl).
9. Create usage examples in [Tests/Examples/](Tests/Examples/).

## (OutDated) Diagrams

[Drawio](https://drive.google.com/file/d/1fkfQfxXt0IOKQ_Q8ngE1mU21Ua7204yd/view?usp=sharing)

## Hardware Issues

Currently Juliagebra works best, without issues on Debian 12 Linux with Xorg GNOME, using NVIDIA GPUs with NVIDIA's proprietary drivers.
Other hardware and software configurations are mostly untested.

### Some known Windows 11 specific issues

- Distant lines can appear fuzzy on AMD GPUs under windows 11.
- Mouse movement feels sluggish, inconsistent, and lumpy.
- Mouse scrolling also feels sluggish, inconsistent, and lumpy.