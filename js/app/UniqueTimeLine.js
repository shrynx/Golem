define(function(){var e;return e=function(){function e(){this.length=0,this.head=new t,this.elems=new t,this.head.prev=this.elems,this.elems.next=this.head,this.now=this.head,this.set={},this.temporary=null}var t;return t=function(){function e(e,t,n){var r,i;this.e=e,this.next=t,this.prev=n,null!=(r=this.prev)&&(r.next=this),null!=(i=this.next)&&(i.prev=this)}return e.prototype.remove=function(){var e;return e=[this.next,this.prev],this.prev.next=e[0],this.next.prev=e[1],e},e}(),e.prototype.push=function(e){var n,r;return r=new t(e,this.head,this.head.prev),n=this.set[e],null!=n?n.remove():this.length++,this.set[e]=r,this.goNewest()},e.prototype.temp=function(e){return this.temporary=e,this.goNewest()},e.prototype.goBack=function(){return null!=this.now.prev.e&&(this.now=this.now.prev),this.curr()},e.prototype.goForward=function(){var e;return e=this.curr(),null!=this.now.e&&(this.now=this.now.next),this.curr()},e.prototype.goOldest=function(){return this.now=this.elems.next,this.curr()},e.prototype.goNewest=function(){return this.now=this.head,this.curr()},e.prototype.isInPast=function(){return this.now!==this.head},e.prototype.curr=function(){return this.now===this.head?this.temporary:this.now.e},e.prototype.newest=function(e){var t,n,r,i,o;for(r=this.head,i=[],n=o=0;(e>=0?e>o:o>e)&&(t=r.prev.e);n=e>=0?++o:--o)i.push(t),r=r.prev;return i.reverse()},e.prototype.from=function(e){var t,n,r;for(n=0,r=e.length;r>n;n++)t=e[n],this.push(t);return this.goNewest()},e.prototype.size=function(){return this.length},e}()});