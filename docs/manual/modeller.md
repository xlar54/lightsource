% renderer65 Modeller
% User's manual
% Draft: screenshots to come

# Introduction

The renderer65 modeller is a 3D scene editor for the MEGA65. You build a scene from simple
shapes, give them materials, place lights and a camera, and then let the MEGA65 ray-trace
it into a 640x200 picture in 256 colours. Pictures are saved as IFF files that most image
programs can open.

Scenes are stored in the modeller's own document format (`.MDL`). The modeller can also
export a scene as text in a subset of POV-Ray's scene language (`.POV`), so you can
render the same scene with POV-Ray on a PC.

Everything runs on the MEGA65: modelling, rendering and saving. A full render takes from
about a minute to tens of minutes, depending on the scene.

[SCREENSHOT: title-render | A finished render of the MEGA65.MDL example]

# Getting started

## Starting the modeller

Insert or mount the renderer65 disk and turn the MEGA65 on. The disk starts itself
(`AUTOBOOT.C65` loads and runs `RENDERER65`). You can also type `RUN "RENDERER65"` at the
`READY.` prompt.

The modeller opens with `DEFAULT.MDL`: an empty scene with a camera, one light and one
white material. The camera is up and back at (7, 5.5, -9), looking down at the origin,
which is where new objects go and where the views are centred. If that file isn't on the disk, the same empty scene is built in.

## What you need

- A MEGA65 (or the Xemu emulator).
- A mouse in port 1. The modeller is made for a mouse; the keyboard has shortcuts for the
  most common commands.

## A first scene in five steps

1. Choose **Add, Sphere**. A sphere appears at the origin, in the middle of the views, and is selected.
2. Choose **Add, Plane** to add a floor, then type `-1` into its **Y** field in the
   properties panel, so the floor sits under the sphere.
3. Click the sphere in the object list, then click **Mat** in the properties panel until
   it shows the material you want (or use **Material, New** to make one).
4. Press **P** for a quick preview. Press any key to come back.
5. Press **R** to render it properly. When the picture is finished, press **S** to save it
   as `SCENE.IFF`, or any other key to go back to the modeller.

[SCREENSHOT: first-scene | The first scene: a sphere on a plane, in the four views]

# The screen

The screen has five parts: the menu bar at the top, four views on the left, the object
list and the properties panel on the right, and the status line at the bottom.

[SCREENSHOT: screen-overview | The whole screen, with its parts labelled]

## The menu bar

Click a menu's name to open it, then click a command. Press ESC, or click anywhere else,
to close a menu without choosing anything. The menus are described in the chapter
"Menu reference".

## The views

There are four views of the scene:

| View | Looks along | Across | Up |
|---|---|---|---|
| Top | down the y axis | x | z |
| Front | the z axis | x | y |
| Side | the x axis | z | y |
| Camera | where the camera points | in perspective | |

The top, front and side views are drawn without perspective, so sizes and distances can be
judged directly. The camera view shows roughly what a render will show.

Objects are drawn as wireframes: spheres as three circles, boxes as their edges, cylinders
and cones as rings with lines along their sides, planes as a grid, prisms as their outline
at the top and bottom, and lathes as rings at each point of their profile. The selected
object is drawn in yellow (all of a group's parts, if a group is selected). Lights are
orange crosses; the camera is a green cross with a line to the point it looks at.

**One large view:** click a view's name (its top-left corner) to make it fill the whole
view area. Click the name again to go back to four views.

[SCREENSHOT: views-large | The front view made large]

## The object list

The list shows everything in the scene, in this order:

- **World**: the background colour and the trace depth (see "World settings").
- **The objects**, as an outline: the parts of a group are indented under it.
- **The lights** (Light 1, Light 2, ...).
- **The camera.**

Click a name to select it. The box at the left of each object shows it in the views
(filled) or hides it (empty): click the box to change it. Hidden objects aren't drawn or
picked in the views, but they are still rendered. Hiding a group hides its parts too
(their names turn grey).

The list shows 11 rows at a time. Use the scroll bar at its right: click above or below
the thumb to move a page, or drag the thumb.

[SCREENSHOT: object-list | The object list with a group, a hidden object and the scroll bar]

## The properties panel

The panel shows the settings of whatever is selected. Click a number to change it: type
the new value on the status line and press RETURN (or ESC to leave it as it was). Clicking
anywhere else also leaves it as it was, and the click then does what it normally would:
click another number to type that one instead. The
status line says what the setting means and, where it helps, its usual range or value:
clicking **Ref** asks "Ref, reflection: 0 none, 1 a perfect mirror:". Click a
name to rename it. Click **Mat** to step to the next material. Click a yes/no setting to
change it.

[SCREENSHOT: properties | The properties panel for a box]

## The status line

The bottom line shows hints and messages ("Added", "Saved", "Nothing to undo", ...) and is
where you type values and file names.

# Working in the views

## Selecting

Click near an object's centre, a light or the camera in any view. The nearest one within a
few pixels is selected. You can also click names in the object list.

## Moving things

Drag the selected object, light or camera in the top, front or side view: it moves in that
view's plane. Inside a group that is turned or scaled, it still follows the pointer. (In the
camera view a drag turns the camera instead: see below.) Each drag can be undone as one
step.

## Turning and sizing with the mouse

Hold a key as you start dragging an object in the top, front or side view:

- **SHIFT:** it turns about the axis that view looks along: RY in the top view, RZ in the
  front view, RX in the side view, a degree for each pixel across.
- **CTRL:** its scale S changes, by 1/64 of itself for each pixel across (right is bigger).

## Snapping to the grid

**View, Snap** (or **G**) turns snapping on or off. While it is on, a drag puts the
position on whole and half units, angles on multiples of 15 degrees, and the scale on
quarters. Corners of prisms and lathes don't snap.

For exact positions, type them into the **X**, **Y** and **Z** fields instead.

## The grid

The top, front and side views show a grid of faint lines, with the axes through the
origin drawn brighter. The spacing follows the zoom: 0.25, 0.5, 1, 2, 5, 10, 20, 50 or
100 units, whichever is the smallest that keeps the lines at least 12 pixels apart. At
the starting zoom the lines are 2 units apart. **View, Grid** turns it off or on again.

## Zooming and centring

- **View, Zoom in** (or **+**) and **View, Zoom out** (or **-**) change the zoom of the
  top, front and side views.
- **View, Locate** (or **L**) centres those three views on the selected object, light or
  camera, keeping the zoom.
- **View, Reset** puts the views back as they were at the start.

## Framing the picture

- **View, Aim camera** (or **A**) points the camera at the selected object or light. It
  stays where it is.
- **View, Camera front**, **Camera top** and **Camera side** look at the selection (or,
  with nothing selected, at the point the camera looked at) from the front (-z), from
  above, or from the side (+x, so that z goes to the right as in the side view), as far
  away as the camera was. From above it is tipped very slightly: a POV-Ray camera can't
  look straight down.
- **Drag on empty space in the camera view** to turn the camera round the point it looks
  at: across the view to go round, up and down to look from higher or lower. The scene
  turns with the pointer, a degree for each pixel, and stops short of straight above or
  below. The distance stays the same.

All of these can be undone.

# Objects

## Adding objects

Choose a shape from the **Add** menu. A new object is placed at the origin (0, 0, 0),
gets the first material, and is selected. If an object was
selected, the new one goes after it in the list (inside it, if it is a group).

| Shape | Its own settings | When added |
|---|---|---|
| Sphere | R: radius | radius 1 |
| Box | SX, SY, SZ: its size along x, y and z (centred) | 2 x 2 x 2 |
| Cylinder | R: radius, H: height (along y, centred) | radius 1, height 2 |
| Cone | R1: radius at the bottom, R2: at the top, H: height | 1, 0 and 2 |
| Plane | (none: the flat ground y = 0, solid below) | |
| Prism | H: height; its corners (see "Prisms") | a house shape, height 1 |
| Lathe | its profile points (see "Lathes") | a chess pawn |

## Settings every object has

| Field | Meaning |
|---|---|
| Name | Up to 11 characters |
| X, Y, Z | Its position |
| RX, RY, RZ | Its rotation in degrees: about x first, then y, then z |
| S | Its scale (the same in every direction) |
| Mat | Its material: click to step to the next one; "(none)" means it takes its group's |

## Groups: union, merge, intersection and difference

A group combines the objects inside it into one shape:

| Group | Result |
|---|---|
| Union | All of its parts together |
| Merge | All of its parts together, without the surfaces inside (better for glass) |
| Intersection | Only where all of its parts overlap |
| Difference | The first part, with all of the others cut away |

To make a group, select an object and choose the group from the **Add** menu: the group is
made around the selected object, at the place where that object was (the object's own
position becomes 0, so nothing moves). Then put more objects into it with **Scene, Indent** (an
object goes into the group just above it in the list).

In a **Difference**, the order matters: the first part is the one that is cut. Use
**Scene, Move up** and **Move down** to change the order.

A group's own position, rotation and scale move all of its parts together, and a material
given to the group is used by every part that has none of its own.

[SCREENSHOT: difference | A box with a sphere cut out of its corner (a Difference)]

## Arranging the list

The **Scene** menu arranges the objects:

- **Move up / Move down** swap the selected object with its neighbour at the same depth.
  (An object with parts, or next to one, can't be swapped this way.)
- **Indent** puts the selected object into the group just above it.
- **Outdent** takes it out of its group.

## Deleting and duplicating

- **Edit, Delete** (or **DEL**) removes the selected object, with all its parts if it is a
  group. It also removes a selected light.
- **Edit, Duplicate** makes a copy of the selected object (and its parts) just after it.

# Prisms and lathes: shapes made of points

## Prisms

A prism is a flat outline of 3 to 16 corners, given a height. The outline can have any
shape, even one that turns back on itself (a star, a letter, an arrow).

When a prism is selected, each corner has a small handle in the top, front and side views
(drawn at the top of the prism). To change the outline:

- **Click a handle** to pick that corner. It fills in, and the panel shows its **CX** and
  **CZ** (you can type them too).
- **Drag the handle** to move the corner.
- **I** adds a corner half way to the next one.
- **DEL** removes the picked corner (a prism keeps at least 3).

**H** in the panel is the prism's height.

[SCREENSHOT: prism-edit | Editing a prism's corners in the top view]

## Lathes

A lathe is a profile turned around the y axis, like a vase or a chess piece on a potter's
wheel. The profile is 2 to 16 points, each a radius and a height.

Lathe points are edited just like prism corners. Their handles are easiest to use in the
front and side views. The panel shows the picked point's **R** (radius) and **Y**
(height).

A lathe is always solid: it can be a vase or a bottle, but not a hollow cup. Each segment
of the profile counts as one shape when the scene is rendered (see "Limits").

[SCREENSHOT: lathe-edit | Editing a lathe's profile in the front view]

## How many points

All the prisms and lathes in a document share a pool of 255 points. Adding a corner says so
when the pool is full.

# Materials

A material sets how a surface looks. A document has up to 16 materials, shared by its
objects.

## Choosing a material

- Click **Mat** in an object's panel to step through the materials.
- **Material, Next** and **Material, Previous** do the same for the selected object.
- **Material, New** makes a copy of the selected object's material, gives it to the object,
  and opens it for editing.
- **Material, Edit** opens the selected object's material in the panel. Select an object to
  go back.

## A library of materials

A material can be kept in a file of its own, `NAME.MAT`, and loaded into any document.

- **Material, Save to file...** saves the material being edited (or the selected object's)
  as `NAME.MAT`. It asks for the name, starting with the material's own.
- **Material, Load from file...** lists the disk's `.MAT` files: click one, or use the
  cursor keys and RETURN. It is added to the document (up to 16 materials), and the
  selected object takes it. With nothing selected, it opens for editing. **Name...** types
  a name instead; **Cancel** or ESC goes back. A load can be undone.

The disk comes with a starter set: BRASS, CHECKER (black and white squares), CHROME,
COPPER, EBONY, GLASS, GLOW (lights itself up, for lamps and screens), GOLD, IVORY, MIRROR,
PLASTIC, RUBBER, TILES (cream and blue squares), WATER and WOOD.

## Material settings

| Field | Meaning |
|---|---|
| Name | Up to 11 characters |
| R, G, B | Its colour (0 to 1 each) |
| Dif | Diffuse: how much light it scatters (0.6 is usual) |
| Pho | Phong: the strength of its highlights |
| Siz | The size of the highlights: larger numbers give smaller, sharper ones |
| Amb | Ambient: the light it shows even in shadow |
| Ref | Reflection: 0 for none, 1 for a perfect mirror |
| Trn | Transmit: how much light passes through (glass is about 0.8) |
| IOR | Index of refraction for transparent materials (glass is 1.5, water 1.33) |
| Checker | yes: a checker pattern of its colour and a second colour |
| Sq | The checker's square size |
| R2, G2, B2 | The checker's second colour |

[SCREENSHOT: material-edit | Editing a material]

# Lights, camera and world

## Lights

**Add, Light** adds a light (up to 16). Its settings:

| Field | Meaning |
|---|---|
| X, Y, Z | Its position |
| R, G, B | Its colour and brightness (1, 1, 1 is white) |
| No shadow | yes: it lights things but casts no shadows |
| Spot | yes: a spotlight, which lights only a cone (the settings below appear) |

## Spotlights

**Add, Spotlight** adds a light with **Spot** already on, aimed at the origin. Any light
can become one by clicking **Spot** in its settings. A spotlight's extra settings:

| Field | Meaning |
|---|---|
| AX, AY, AZ | The point it aims at |
| Rad | The cone of full light: degrees from its centre line (30 to start) |
| Fal | Where the light ends, in degrees (45 to start). Between Rad and Fal it fades out smoothly. Kept to at least Rad and at most 90 |
| Tgt | Tightness: above 0 the light dims towards the edge of the cone as well (10 is a lot) |

In the views a spotlight is drawn with a line to its aim point, a small cross there, and
its cone out to that point: four lines from the light and a ring round the aim point,
square to the line. The ring shows Fal, so a wide cone aimed far away is drawn large:
zoom out to see it all.

To aim it:
- **Drag the aim point's cross** in the top, front or side view. The light stays where it
  is.
- **View, Aim light...**, with the light selected, then click an object, a light or the
  camera in a view: the spotlight aims at its centre. Clicking empty space leaves the
  aim as it was.
- Type **AX**, **AY** and **AZ** in the panel.

## The camera

Select **Camera** in the list. Its settings:

| Field | Meaning |
|---|---|
| X, Y, Z | Where it is |
| LX, LY, LZ | The point it looks at |
| Ang | How wide it sees, in degrees across the picture |

## World settings

Choose **Scene, World...** or click **World** at the top of the list:

| Field | Meaning |
|---|---|
| BgR, BgG, BgB | The background colour, seen where nothing is hit |
| Trace | How many bounces reflections and glass get (POV-Ray's max_trace_level) |

# Undo and redo

**Edit, Undo** (**U** or **Ctrl-Z**) takes back the last change, and **Edit, Redo** (**Y**
or **Ctrl-Y**) puts it back. The modeller keeps the last 16 changes.

A change is anything that alters the document: adding, deleting, moving, typing a value,
changing a material, editing corners, the show and hide boxes, and also **New** and
**Open**. Selecting, zooming and rendering aren't changes. Making a new change after undoing
drops what could have been redone.

# Rendering

## Preview

**File, Preview** (or **P**) traces every fourth pixel of every second line, with at most
one bounce: a quick check of the lighting and layout. Press any key or click to go back.

## Render

**File, Render** (or **R**) traces every pixel and then works out the best 256 colours for
the picture. While it works, a rough preview builds up line by line. When it is finished
the picture is shown on its own:

- **S** saves it as an IFF file named after the document (`SCENE.IFF`, for example).
- Any other key, or a click, goes back to the modeller.

Rendering time depends on how many shapes there are, how many lights, and how much glass and
mirror the scene has. A few shapes take a minute or two; a big scene with glass can take
much longer.

[SCREENSHOT: render-shown | A finished render, shown full screen]

## Looking at pictures later

The disk has a picture viewer, `VIEWER`, written in BASIC 65. Leave the modeller with
**File, Exit** and type `RUN "VIEWER"`. It lists the pictures on the disk: type a
picture's name and press RETURN to see it, and press any key to come back to the list.
Press RETURN on its own to stop.

Your own BASIC programs can show the pictures too: `SCREEN 640,200,8` then
`LOADIFF "NAME.IFF"`, and `SCREEN CLOSE` afterwards.

[SCREENSHOT: viewer | The picture viewer's list of pictures]

## About the pictures

The IFF files are 640x200 with 256 colours (8 bitplanes). The MEGA65's pixels are taller
than they are wide, and the files record that, so viewers show the right shape.

# Files

| Command | What it does |
|---|---|
| File, New | Starts again from DEFAULT.MDL (can be undone) |
| File, Open... | Lists the disk's documents: click one, or use the cursor keys and RETURN. Name... types a name instead; Cancel or ESC goes back |
| File, Save | Saves the document as NAME.MDL |
| File, Save as... | Asks for a new name, then saves |
| File, Export POV | Writes the scene as POV-Ray text, NAME.POV |
| Material, Save to file... / Load from file... | A material on its own, NAME.MAT (see "A library of materials") |
| File, Exit | Asks first, then goes back to BASIC (anything not saved is lost) |

File names are up to 12 characters, without the extension. A new document is called
`SCENE`.

[SCREENSHOT: open-dialog | The Open list]

## DEFAULT.MDL

The modeller starts with `DEFAULT.MDL`, and **File, New** loads it too. To make your own
starting point, build it and **Save as** `DEFAULT`. The document is still called `SCENE`
after loading it, so a plain **Save** never overwrites `DEFAULT.MDL` by accident.

## The examples

| File | What it is |
|---|---|
| TINYRAY.MDL | Four spheres (ivory, glass, rubber, mirror) over a checker board |
| MEGA65.MDL | The word MEGA65 in prisms, with glass balls, gold cones and a mirror ball |
| JUGGLER.MDL | A robot juggling three mirror balls over a checker floor |
| CHESS.MDL | A king, a rook and a knight on a board: lathes, boxes and a prism |
| CHESSSET.MDL | A whole chess set in its starting position |
| DESK.MDL | A desk at night: computer, monitor, keyboard and mouse, lit only by a desk lamp's spotlight |
| TIE.MDL | A TIE fighter in space, with a planet and stars on a black background |

## POV-Ray files

**Export POV** writes the scene in a subset of POV-Ray's language, readable by POV-Ray 3.7.
To frame the picture the same way, render it in POV-Ray at 640x375. The modeller can't
read `.POV` files back.

# Keyboard reference

| Key | Does |
|---|---|
| U or Ctrl-Z | Undo |
| Y or Ctrl-Y | Redo |
| DEL | Delete the picked corner, or the selected object or light |
| I (or INST) | Add a corner after the picked one |
| + / - | Zoom in / out |
| L | Locate the selection |
| A | Aim the camera at the selection |
| G | Snap on or off |
| P | Preview |
| R | Render |
| S | Save |
| ESC | Close a menu, or stop typing without changing anything |
| RETURN | Accept what was typed |

# Menu reference

| Menu | Commands |
|---|---|
| File | New, Open..., Save, Save as..., Export POV, Preview, Render, Exit |
| Edit | Undo, Redo, Delete, Duplicate |
| Scene | Move up, Move down, Indent, Outdent, World... |
| Add | Sphere, Box, Cylinder, Cone, Plane, Prism, Lathe, Light, Spotlight, Union, Merge, Intersection, Difference |
| Material | Next, Previous, New (a copy), Edit, Save to file..., Load from file... |
| View | Zoom in, Zoom out, Locate, Reset, Aim camera, Aim light..., Camera front, Camera top, Camera side, Snap, Grid |

[SCREENSHOT: menus | The menus, open]

# Limits

| What | Limit |
|---|---|
| Objects (shapes and groups) | 64 |
| Materials | 16 |
| Lights | 16 |
| Corners of one prism | 3 to 16 |
| Points of one lathe | 2 to 16 |
| Prism and lathe points in a document | 255 |
| Shapes in a render (each lathe segment is one; groups don't count) | 64 |
| Undo steps | 16 |
| Documents in the Open list | 48 |
| File names | 12 characters |

Numbers are kept in 16.16 fixed point: up to about 4 decimal places count, and every value
must stay below 32767. Keep the scene within about 120 units of the camera.

# Tips

- **Speckled surfaces:** two surfaces in exactly the same place (a box's bottom resting on a
  plane at the same height, say) fight over which is seen. Lift one a little.
- **Glass and shadows:** glass casts a full shadow, as in the original tinyraytracer. For a
  lighter look, use a second light with **No shadow**.
- **Glass looks dark:** raise **Trace** in the world settings so rays get through more
  surfaces (each costs time).
- **Faster renders:** fewer shapes, fewer lights, and less glass and mirror. Hidden objects
  still render, so delete what you don't need.
- **Checker floors:** a plane with a **Checker** material and **Sq** of 1 to 2 looks good.
- **Keep the scene within about 150 units of the camera and the lights.** The tracer's
  numbers can't hold distances much past 180 units, and anything further away comes out
  garbled. For something far off, like a planet or stars, make it small and bring it in
  closer: a planet of radius 11 at 75 units looks the same as one of radius 33 at 225.
  `TIE.MDL` does this.
