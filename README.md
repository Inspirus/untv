![UNTV](https://raw.github.com/untv/untv/master/src/assets/images/untv-logo.png)

UNTV is a cross platform DRM-free media platform for home theater computers. 
Developers should read "Getting Started" and the [API Documentation](http://untvapp.com/api.html).

## Getting Started

### End Users

Download the [latest bundled release](https://github.com/untv/untv/releases) for your platform and place in your Applications directory (or equivalent) and launch as usual. 

#### Using the Keyboard as a Remote

If you are developing for UNTV or do not wish to use your smartphone as a 
remote control, you may use your keyboard as a remote. Below is a list of 
the different keys and combinations as well as their targeted `event`. For 
more information about these events from a development perspective, you will 
likely need to read `extending-the-remote.md`.

* **Up Arrow**: Scroll Up
* **Left Arrow**: Scroll Left
* **Right Arrow**: Scroll Right
* **Down Arrow**: Scroll Down
* **Home**: Toggle Menu
* **Esc**: Go Back
* **Tab**: Go Next
* **Enter**: Select
* **Space**: Pause/Play Player
* **Shift + Left Arrow**: Seek Player Previous
* **Shift + Right Arrow**: Seek Player Next

### Developers

Since UNTV aims to provide support for as many codecs as possible, it uses a custom build of [Node-Webkit](https://github.com/rogerwang/node-webkit) which I have compiled for linux64, darwin32, and win32. You may, however, use the upstream builds of Node-Webkit, but you will sacrifice playback support for just about everything except for `.ogg` and `.webm`. 

Clone the repository:

```
~# git clone https://github.com/untv/untv.git
```

Install dependencies using Node Package Manager:

```
~# cd untv && sudo npm install
```

Make sure you have CoffeeScript installed globally (we use `cake` for tasks):

```
~# sudo npm install coffee-script -g
```

Run `cake setup` from the project root to download your platform's custom build of node-webkit and unpack it to the `bin/` directory.

> Alternatively download the custom build of node-webkit here: 
> https://file.ac/s4Lt3Vo6rls/
> Then, unzip and place contents in the `bin/nw-0.8.4-custom` directory.

Run `cake start` from the project root to launch UNTV.

Run `cake build` from the project root to bundle a distributable release for your platform.
