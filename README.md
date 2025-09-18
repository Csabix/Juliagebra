# Juliagebra

Geogebra like 3D interactive plotting libary written in Julia and OpenGL.

## Used Packages

Every package used by Juliagebra can be found in the [Project.toml](Project.toml) file.

For some examples **DifferentialEquations** package is needed, which may downgrade your **DataStructures** package.

Juliagebra depends on a package called [JuliaGLM](https://github.com/Csabix/JuliaGLM), which is currently not available in the official Julia package repository.

Because of this, it is recommended, that you clone [JuliaGLM](https://github.com/Csabix/JuliaGLM) from it's official repository, then by ``` develop ```-ing it, you tell Julia, where this package is.

## Examples

Scripts which showcase the use of the library can be found inside [examples/](examples/).

Camera movement is just like in Blender:
- Look around by holding down the scroll wheel, and moving the mouse.
- Pan the camera by doing the same, but holding down the shift key.
- Scroll to zoom in-and-out.

To run the examples without installing the package globally:
```
julia --project=. examples/example.jl
```

But if you want to install the module globally, while cd-d in the root of this project, run:
```
julia
]
develop .
```

Now the package is available for use in your global Julia module scope.

## Creating dependents

For how a Non-Rendered/Rendered Dependent can be created, a good place to start is [intersections.jl](src/Dependents/intersections.jl) and [point.jl](src/Dependents/point.jl).

Highly suggested steps for creating a Dependent:
1. Create a file for it in the [src/Dependents/](src/Dependents/) folder.
2. Include the created file in [Juliagebra.jl](src/Juliagebra.jl) below the **Dependents** section.
3. Additional helper files should go in the [src/Helpers/](src/Helpers/) folder.
4. Helper files can be included in [Juliagebra.jl](src/Juliagebra.jl) below the **Helpers** section, or dierctly above the dependent's include, if nothing else uses it.
5. Create a **Plan**.
6. Create a **Dependent**.
7. If needed create a **Renderer**.
8. Once done, create a User accessible (exported) constructor function in [constructors.jl](src/constructors.jl).
9. Create usage examples in [examples/](examples/).

## Package commands

For adding or removing packages Juliagebra depends on, run theese commands while you're cd-d into the root of this project, but try to keep the versions of the packages as free as possible in the [Project.toml](Project.toml) file.

### Add Dependent Packages:
```
julia
]
activate .
add PackageName
```

### Add Local Packages:
```
julia
]
activate .
develop path/to/package/relative/to/Juliagebra/root/folder
```

After adding local packages, it is reccomended, to run a ``` resolve ``` and ``` instantiate ``` command in both the global package scope, and in the Juliagebra package scope.

### Remove Dependent Packages:
```
julia
]
activate .
rm PackageName
```

## Tests

Write tests in a seperate file in the [test/](test/) folder, and include them in [runtests.jl](test/runtests.jl).

To run the tests, while you're cd-d in the root of this project, run theese commands:
```
julia
]
activate .
test
```

## Diagrams

[Drawio](https://drive.google.com/file/d/1fkfQfxXt0IOKQ_Q8ngE1mU21Ua7204yd/view?usp=sharing)

## Most Stable Hardware

Currently Juliagebra works best, without issues on Debian 12/13 or Ubuntu 24.04 LTS Linux with Xorg GNOME, using NVIDIA GPUs with NVIDIA's proprietary drivers.