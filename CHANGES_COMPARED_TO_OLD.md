Most of the node interace functions can be found inside src/Graph/node.jl

update: called every frame with the delta time
convert_callback_entry: Converts the node before passing to the callback e.g Point -> Vec3D
convert_callback_result: Convert the callback to appropriate type e.g Vec3D (from the callback) -> Point
eval_node: calls the callback
render_node: Used when the node is visible in the scene e.g Point
render_node_gui: Used when the node is visible in the gui e.g Slider
edit_node: If you want your node to be editable from the gui
edit_node_overload: set it true if edit_node is overloaded

on_gizmo_select: Called when the user right clicks the object
on_gizmo_move: Called when the gizmo is moved

eval_geometry_node: Calls convert_callback_entry, convert_callback_result, eval_node

When you add an element to the graph you get back a NodeHandle and you reference it by that, because the graph can accept immutable elements too.
NodeHandle == ID == location in GeometryPlotGraph.elements/nodes

You add elements to the graph by calling add_node!

The goal is to make it easy to add any kind of element to the graph.
Interface functions use default values so users can easily add graph elements by overriding only the necessary methods.