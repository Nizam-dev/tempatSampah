canvas = document.getElementById("canvas");
context = canvas.getContext("2d");
canvas.width= canvas.scrollWidth;
 canvas.height = canvas.scrollHeight;


var a = context.createLinearGradient(0,0,canvas.width,canvas.height);
a.addColorStop(0,'red');
a.addColorStop(1,'blue');
function draw() {

    

    context.save();
  
    context.fillStyle = a;
    context.fillRect(30,250,100,150);
    context.fillStyle= 'blue';
    context.fillRect(30,250,100,10);
    context.fillStyle = 'yellow';
    context.fillRect(70,225,25,25);
    context.restore();
				

 }
draw();