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
	
	// tempat sampah 2 dan 3 
	context.save();
     context.fillStyle = a;
     context.fillRect(160,250,100,150);
     context.translate(265,245);
     context.rotate((Math.PI/180)*35);
     context.scale(-1,1);
     context.fillStyle= 'blue';
     context.fillRect(0,0,100,10);
     context.fillStyle = 'yellow';
     context.fillRect(35,-25,25,25);
     context.restore();



  context.save();
     context.fillStyle = a;
     context.fillRect(290,250,100,150);
     context.translate(390,250);
     context.rotate((Math.PI/180)*90);
     context.scale(-1,1);
     context.fillStyle= 'blue';
     context.fillRect(0,0,100,10);
     context.fillStyle = 'yellow';
     context.fillRect(35,-25,30,25);
     context.restore();
				

 }
draw();


//animasi sampah

var rotation = 0;
var dr = 0.04;
function dra() {

   // reset transforms before clearing
   
  context.clearRect(430, 100, 140,150);

   context.save();
   context.fillStyle = a;
   context.fillRect(450,250,100,150);
   context.translate(540, 250);
   context.scale(1,-1);
   requestAnimationFrame(dra);
   context.rotate(rotation);
   context.fillStyle = 'blue';
   context.fillRect(0,0,10,90);
   context.fillStyle = 'yellow';
   context.fillRect(0,25,30,30);

   context.restore();
  
  if(rotation >=1.6 || rotation < 0 ){
      dr =- dr; 
     }
     rotation +=dr;


}

dra();

 
