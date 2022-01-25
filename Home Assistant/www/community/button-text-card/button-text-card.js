/*! *****************************************************************************
Copyright (c) Microsoft Corporation. All rights reserved.
Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at http://www.apache.org/licenses/LICENSE-2.0

THIS CODE IS PROVIDED ON AN *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
MERCHANTABLITY OR NON-INFRINGEMENT.

See the Apache Version 2.0 License for specific language governing permissions
and limitations under the License.
***************************************************************************** */
function t(t,e,n,i){var s,o=arguments.length,r=o<3?e:null===i?i=Object.getOwnPropertyDescriptor(e,n):i;if("object"==typeof Reflect&&"function"==typeof Reflect.decorate)r=Reflect.decorate(t,e,n,i);else for(var a=t.length-1;a>=0;a--)(s=t[a])&&(r=(o<3?s(r):o>3?s(e,n,r):s(e,n))||r);return o>3&&r&&Object.defineProperty(e,n,r),r
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */}const e="undefined"!=typeof window&&null!=window.customElements&&void 0!==window.customElements.polyfillWrapFlushCallback,n=(t,e,n=null)=>{for(;e!==n;){const n=e.nextSibling;t.removeChild(e),e=n}},i=`{{lit-${String(Math.random()).slice(2)}}}`,s=`\x3c!--${i}--\x3e`,o=new RegExp(`${i}|${s}`);class r{constructor(t,e){this.parts=[],this.element=e;const n=[],s=[],r=document.createTreeWalker(e.content,133,null,!1);let c=0,h=-1,u=0;const{strings:p,values:{length:m}}=t;for(;u<m;){const t=r.nextNode();if(null!==t){if(h++,1===t.nodeType){if(t.hasAttributes()){const e=t.attributes,{length:n}=e;let i=0;for(let t=0;t<n;t++)a(e[t].name,"$lit$")&&i++;for(;i-- >0;){const e=p[u],n=d.exec(e)[2],i=n.toLowerCase()+"$lit$",s=t.getAttribute(i);t.removeAttribute(i);const r=s.split(o);this.parts.push({type:"attribute",index:h,name:n,strings:r}),u+=r.length-1}}"TEMPLATE"===t.tagName&&(s.push(t),r.currentNode=t.content)}else if(3===t.nodeType){const e=t.data;if(e.indexOf(i)>=0){const i=t.parentNode,s=e.split(o),r=s.length-1;for(let e=0;e<r;e++){let n,o=s[e];if(""===o)n=l();else{const t=d.exec(o);null!==t&&a(t[2],"$lit$")&&(o=o.slice(0,t.index)+t[1]+t[2].slice(0,-"$lit$".length)+t[3]),n=document.createTextNode(o)}i.insertBefore(n,t),this.parts.push({type:"node",index:++h})}""===s[r]?(i.insertBefore(l(),t),n.push(t)):t.data=s[r],u+=r}}else if(8===t.nodeType)if(t.data===i){const e=t.parentNode;null!==t.previousSibling&&h!==c||(h++,e.insertBefore(l(),t)),c=h,this.parts.push({type:"node",index:h}),null===t.nextSibling?t.data="":(n.push(t),h--),u++}else{let e=-1;for(;-1!==(e=t.data.indexOf(i,e+1));)this.parts.push({type:"node",index:-1}),u++}}else r.currentNode=s.pop()}for(const t of n)t.parentNode.removeChild(t)}}const a=(t,e)=>{const n=t.length-e.length;return n>=0&&t.slice(n)===e},c=t=>-1!==t.index,l=()=>document.createComment(""),d=/([ \x09\x0a\x0c\x0d])([^\0-\x1F\x7F-\x9F "'>=/]+)([ \x09\x0a\x0c\x0d]*=[ \x09\x0a\x0c\x0d]*(?:[^ \x09\x0a\x0c\x0d"'`<>=]*|"[^"]*|'[^']*))$/;function h(t,e){const{element:{content:n},parts:i}=t,s=document.createTreeWalker(n,133,null,!1);let o=p(i),r=i[o],a=-1,c=0;const l=[];let d=null;for(;s.nextNode();){a++;const t=s.currentNode;for(t.previousSibling===d&&(d=null),e.has(t)&&(l.push(t),null===d&&(d=t)),null!==d&&c++;void 0!==r&&r.index===a;)r.index=null!==d?-1:r.index-c,o=p(i,o),r=i[o]}l.forEach(t=>t.parentNode.removeChild(t))}const u=t=>{let e=11===t.nodeType?0:1;const n=document.createTreeWalker(t,133,null,!1);for(;n.nextNode();)e++;return e},p=(t,e=-1)=>{for(let n=e+1;n<t.length;n++){const e=t[n];if(c(e))return n}return-1};
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */
const m=new WeakMap,f=t=>"function"==typeof t&&m.has(t),g={},_={};
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */
class y{constructor(t,e,n){this.__parts=[],this.template=t,this.processor=e,this.options=n}update(t){let e=0;for(const n of this.__parts)void 0!==n&&n.setValue(t[e]),e++;for(const t of this.__parts)void 0!==t&&t.commit()}_clone(){const t=e?this.template.element.content.cloneNode(!0):document.importNode(this.template.element.content,!0),n=[],i=this.template.parts,s=document.createTreeWalker(t,133,null,!1);let o,r=0,a=0,l=s.nextNode();for(;r<i.length;)if(o=i[r],c(o)){for(;a<o.index;)a++,"TEMPLATE"===l.nodeName&&(n.push(l),s.currentNode=l.content),null===(l=s.nextNode())&&(s.currentNode=n.pop(),l=s.nextNode());if("node"===o.type){const t=this.processor.handleTextExpression(this.options);t.insertAfterNode(l.previousSibling),this.__parts.push(t)}else this.__parts.push(...this.processor.handleAttributeExpressions(l,o.name,o.strings,this.options));r++}else this.__parts.push(void 0),r++;return e&&(document.adoptNode(t),customElements.upgrade(t)),t}}
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */const v=` ${i} `;class w{constructor(t,e,n,i){this.strings=t,this.values=e,this.type=n,this.processor=i}getHTML(){const t=this.strings.length-1;let e="",n=!1;for(let o=0;o<t;o++){const t=this.strings[o],r=t.lastIndexOf("\x3c!--");n=(r>-1||n)&&-1===t.indexOf("--\x3e",r+1);const a=d.exec(t);e+=null===a?t+(n?v:s):t.substr(0,a.index)+a[1]+a[2]+"$lit$"+a[3]+i}return e+=this.strings[t],e}getTemplateElement(){const t=document.createElement("template");return t.innerHTML=this.getHTML(),t}}
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */const b=t=>null===t||!("object"==typeof t||"function"==typeof t),S=t=>Array.isArray(t)||!(!t||!t[Symbol.iterator]);class x{constructor(t,e,n){this.dirty=!0,this.element=t,this.name=e,this.strings=n,this.parts=[];for(let t=0;t<n.length-1;t++)this.parts[t]=this._createPart()}_createPart(){return new C(this)}_getValue(){const t=this.strings,e=t.length-1;let n="";for(let i=0;i<e;i++){n+=t[i];const e=this.parts[i];if(void 0!==e){const t=e.value;if(b(t)||!S(t))n+="string"==typeof t?t:String(t);else for(const e of t)n+="string"==typeof e?e:String(e)}}return n+=t[e],n}commit(){this.dirty&&(this.dirty=!1,this.element.setAttribute(this.name,this._getValue()))}}class C{constructor(t){this.value=void 0,this.committer=t}setValue(t){t===g||b(t)&&t===this.value||(this.value=t,f(t)||(this.committer.dirty=!0))}commit(){for(;f(this.value);){const t=this.value;this.value=g,t(this)}this.value!==g&&this.committer.commit()}}class P{constructor(t){this.value=void 0,this.__pendingValue=void 0,this.options=t}appendInto(t){this.startNode=t.appendChild(l()),this.endNode=t.appendChild(l())}insertAfterNode(t){this.startNode=t,this.endNode=t.nextSibling}appendIntoPart(t){t.__insert(this.startNode=l()),t.__insert(this.endNode=l())}insertAfterPart(t){t.__insert(this.startNode=l()),this.endNode=t.endNode,t.endNode=this.startNode}setValue(t){this.__pendingValue=t}commit(){if(null===this.startNode.parentNode)return;for(;f(this.__pendingValue);){const t=this.__pendingValue;this.__pendingValue=g,t(this)}const t=this.__pendingValue;t!==g&&(b(t)?t!==this.value&&this.__commitText(t):t instanceof w?this.__commitTemplateResult(t):t instanceof Node?this.__commitNode(t):S(t)?this.__commitIterable(t):t===_?(this.value=_,this.clear()):this.__commitText(t))}__insert(t){this.endNode.parentNode.insertBefore(t,this.endNode)}__commitNode(t){this.value!==t&&(this.clear(),this.__insert(t),this.value=t)}__commitText(t){const e=this.startNode.nextSibling,n="string"==typeof(t=null==t?"":t)?t:String(t);e===this.endNode.previousSibling&&3===e.nodeType?e.data=n:this.__commitNode(document.createTextNode(n)),this.value=t}__commitTemplateResult(t){const e=this.options.templateFactory(t);if(this.value instanceof y&&this.value.template===e)this.value.update(t.values);else{const n=new y(e,t.processor,this.options),i=n._clone();n.update(t.values),this.__commitNode(i),this.value=n}}__commitIterable(t){Array.isArray(this.value)||(this.value=[],this.clear());const e=this.value;let n,i=0;for(const s of t)n=e[i],void 0===n&&(n=new P(this.options),e.push(n),0===i?n.appendIntoPart(this):n.insertAfterPart(e[i-1])),n.setValue(s),n.commit(),i++;i<e.length&&(e.length=i,this.clear(n&&n.endNode))}clear(t=this.startNode){n(this.startNode.parentNode,t.nextSibling,this.endNode)}}class T{constructor(t,e,n){if(this.value=void 0,this.__pendingValue=void 0,2!==n.length||""!==n[0]||""!==n[1])throw new Error("Boolean attributes can only contain a single expression");this.element=t,this.name=e,this.strings=n}setValue(t){this.__pendingValue=t}commit(){for(;f(this.__pendingValue);){const t=this.__pendingValue;this.__pendingValue=g,t(this)}if(this.__pendingValue===g)return;const t=!!this.__pendingValue;this.value!==t&&(t?this.element.setAttribute(this.name,""):this.element.removeAttribute(this.name),this.value=t),this.__pendingValue=g}}class N extends x{constructor(t,e,n){super(t,e,n),this.single=2===n.length&&""===n[0]&&""===n[1]}_createPart(){return new E(this)}_getValue(){return this.single?this.parts[0].value:super._getValue()}commit(){this.dirty&&(this.dirty=!1,this.element[this.name]=this._getValue())}}class E extends C{}let M=!1;(()=>{try{const t={get capture(){return M=!0,!1}};window.addEventListener("test",t,t),window.removeEventListener("test",t,t)}catch(t){}})();class k{constructor(t,e,n){this.value=void 0,this.__pendingValue=void 0,this.element=t,this.eventName=e,this.eventContext=n,this.__boundHandleEvent=t=>this.handleEvent(t)}setValue(t){this.__pendingValue=t}commit(){for(;f(this.__pendingValue);){const t=this.__pendingValue;this.__pendingValue=g,t(this)}if(this.__pendingValue===g)return;const t=this.__pendingValue,e=this.value,n=null==t||null!=e&&(t.capture!==e.capture||t.once!==e.once||t.passive!==e.passive),i=null!=t&&(null==e||n);n&&this.element.removeEventListener(this.eventName,this.__boundHandleEvent,this.__options),i&&(this.__options=A(t),this.element.addEventListener(this.eventName,this.__boundHandleEvent,this.__options)),this.value=t,this.__pendingValue=g}handleEvent(t){"function"==typeof this.value?this.value.call(this.eventContext||this.element,t):this.value.handleEvent(t)}}const A=t=>t&&(M?{capture:t.capture,passive:t.passive,once:t.once}:t.capture)
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */;function D(t){let e=O.get(t.type);void 0===e&&(e={stringsArray:new WeakMap,keyString:new Map},O.set(t.type,e));let n=e.stringsArray.get(t.strings);if(void 0!==n)return n;const s=t.strings.join(i);return n=e.keyString.get(s),void 0===n&&(n=new r(t,t.getTemplateElement()),e.keyString.set(s,n)),e.stringsArray.set(t.strings,n),n}const O=new Map,V=new WeakMap;
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */const R=new
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */
class{handleAttributeExpressions(t,e,n,i){const s=e[0];if("."===s){return new N(t,e.slice(1),n).parts}return"@"===s?[new k(t,e.slice(1),i.eventContext)]:"?"===s?[new T(t,e.slice(1),n)]:new x(t,e,n).parts}handleTextExpression(t){return new P(t)}};
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */"undefined"!=typeof window&&(window.litHtmlVersions||(window.litHtmlVersions=[])).push("1.2.1");const Y=(t,...e)=>new w(t,e,"html",R)
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */,U=(t,e)=>`${t}--${e}`;let H=!0;void 0===window.ShadyCSS?H=!1:void 0===window.ShadyCSS.prepareTemplateDom&&(console.warn("Incompatible ShadyCSS version detected. Please update to at least @webcomponents/webcomponentsjs@2.0.2 and @webcomponents/shadycss@1.3.1."),H=!1);const j=t=>e=>{const n=U(e.type,t);let s=O.get(n);void 0===s&&(s={stringsArray:new WeakMap,keyString:new Map},O.set(n,s));let o=s.stringsArray.get(e.strings);if(void 0!==o)return o;const a=e.strings.join(i);if(o=s.keyString.get(a),void 0===o){const n=e.getTemplateElement();H&&window.ShadyCSS.prepareTemplateDom(n,t),o=new r(e,n),s.keyString.set(a,o)}return s.stringsArray.set(e.strings,o),o},$=["html","svg"],z=new Set,L=(t,e,n)=>{z.add(t);const i=n?n.element:document.createElement("template"),s=e.querySelectorAll("style"),{length:o}=s;if(0===o)return void window.ShadyCSS.prepareTemplateStyles(i,t);const r=document.createElement("style");for(let t=0;t<o;t++){const e=s[t];e.parentNode.removeChild(e),r.textContent+=e.textContent}(t=>{$.forEach(e=>{const n=O.get(U(e,t));void 0!==n&&n.keyString.forEach(t=>{const{element:{content:e}}=t,n=new Set;Array.from(e.querySelectorAll("style")).forEach(t=>{n.add(t)}),h(t,n)})})})(t);const a=i.content;n?function(t,e,n=null){const{element:{content:i},parts:s}=t;if(null==n)return void i.appendChild(e);const o=document.createTreeWalker(i,133,null,!1);let r=p(s),a=0,c=-1;for(;o.nextNode();){for(c++,o.currentNode===n&&(a=u(e),n.parentNode.insertBefore(e,n));-1!==r&&s[r].index===c;){if(a>0){for(;-1!==r;)s[r].index+=a,r=p(s,r);return}r=p(s,r)}}}(n,r,a.firstChild):a.insertBefore(r,a.firstChild),window.ShadyCSS.prepareTemplateStyles(i,t);const c=a.querySelector("style");if(window.ShadyCSS.nativeShadow&&null!==c)e.insertBefore(c.cloneNode(!0),e.firstChild);else if(n){a.insertBefore(r,a.firstChild);const t=new Set;t.add(r),h(n,t)}};window.JSCompiler_renameProperty=(t,e)=>t;const F={toAttribute(t,e){switch(e){case Boolean:return t?"":null;case Object:case Array:return null==t?t:JSON.stringify(t)}return t},fromAttribute(t,e){switch(e){case Boolean:return null!==t;case Number:return null===t?null:Number(t);case Object:case Array:return JSON.parse(t)}return t}},q=(t,e)=>e!==t&&(e==e||t==t),I={attribute:!0,type:String,converter:F,reflect:!1,hasChanged:q};class B extends HTMLElement{constructor(){super(),this._updateState=0,this._instanceProperties=void 0,this._updatePromise=new Promise(t=>this._enableUpdatingResolver=t),this._changedProperties=new Map,this._reflectingProperties=void 0,this.initialize()}static get observedAttributes(){this.finalize();const t=[];return this._classProperties.forEach((e,n)=>{const i=this._attributeNameForProperty(n,e);void 0!==i&&(this._attributeToPropertyMap.set(i,n),t.push(i))}),t}static _ensureClassProperties(){if(!this.hasOwnProperty(JSCompiler_renameProperty("_classProperties",this))){this._classProperties=new Map;const t=Object.getPrototypeOf(this)._classProperties;void 0!==t&&t.forEach((t,e)=>this._classProperties.set(e,t))}}static createProperty(t,e=I){if(this._ensureClassProperties(),this._classProperties.set(t,e),e.noAccessor||this.prototype.hasOwnProperty(t))return;const n="symbol"==typeof t?Symbol():"__"+t,i=this.getPropertyDescriptor(t,n,e);void 0!==i&&Object.defineProperty(this.prototype,t,i)}static getPropertyDescriptor(t,e,n){return{get(){return this[e]},set(n){const i=this[t];this[e]=n,this._requestUpdate(t,i)},configurable:!0,enumerable:!0}}static getPropertyOptions(t){return this._classProperties&&this._classProperties.get(t)||I}static finalize(){const t=Object.getPrototypeOf(this);if(t.hasOwnProperty("finalized")||t.finalize(),this.finalized=!0,this._ensureClassProperties(),this._attributeToPropertyMap=new Map,this.hasOwnProperty(JSCompiler_renameProperty("properties",this))){const t=this.properties,e=[...Object.getOwnPropertyNames(t),..."function"==typeof Object.getOwnPropertySymbols?Object.getOwnPropertySymbols(t):[]];for(const n of e)this.createProperty(n,t[n])}}static _attributeNameForProperty(t,e){const n=e.attribute;return!1===n?void 0:"string"==typeof n?n:"string"==typeof t?t.toLowerCase():void 0}static _valueHasChanged(t,e,n=q){return n(t,e)}static _propertyValueFromAttribute(t,e){const n=e.type,i=e.converter||F,s="function"==typeof i?i:i.fromAttribute;return s?s(t,n):t}static _propertyValueToAttribute(t,e){if(void 0===e.reflect)return;const n=e.type,i=e.converter;return(i&&i.toAttribute||F.toAttribute)(t,n)}initialize(){this._saveInstanceProperties(),this._requestUpdate()}_saveInstanceProperties(){this.constructor._classProperties.forEach((t,e)=>{if(this.hasOwnProperty(e)){const t=this[e];delete this[e],this._instanceProperties||(this._instanceProperties=new Map),this._instanceProperties.set(e,t)}})}_applyInstanceProperties(){this._instanceProperties.forEach((t,e)=>this[e]=t),this._instanceProperties=void 0}connectedCallback(){this.enableUpdating()}enableUpdating(){void 0!==this._enableUpdatingResolver&&(this._enableUpdatingResolver(),this._enableUpdatingResolver=void 0)}disconnectedCallback(){}attributeChangedCallback(t,e,n){e!==n&&this._attributeToProperty(t,n)}_propertyToAttribute(t,e,n=I){const i=this.constructor,s=i._attributeNameForProperty(t,n);if(void 0!==s){const t=i._propertyValueToAttribute(e,n);if(void 0===t)return;this._updateState=8|this._updateState,null==t?this.removeAttribute(s):this.setAttribute(s,t),this._updateState=-9&this._updateState}}_attributeToProperty(t,e){if(8&this._updateState)return;const n=this.constructor,i=n._attributeToPropertyMap.get(t);if(void 0!==i){const t=n.getPropertyOptions(i);this._updateState=16|this._updateState,this[i]=n._propertyValueFromAttribute(e,t),this._updateState=-17&this._updateState}}_requestUpdate(t,e){let n=!0;if(void 0!==t){const i=this.constructor,s=i.getPropertyOptions(t);i._valueHasChanged(this[t],e,s.hasChanged)?(this._changedProperties.has(t)||this._changedProperties.set(t,e),!0!==s.reflect||16&this._updateState||(void 0===this._reflectingProperties&&(this._reflectingProperties=new Map),this._reflectingProperties.set(t,s))):n=!1}!this._hasRequestedUpdate&&n&&(this._updatePromise=this._enqueueUpdate())}requestUpdate(t,e){return this._requestUpdate(t,e),this.updateComplete}async _enqueueUpdate(){this._updateState=4|this._updateState;try{await this._updatePromise}catch(t){}const t=this.performUpdate();return null!=t&&await t,!this._hasRequestedUpdate}get _hasRequestedUpdate(){return 4&this._updateState}get hasUpdated(){return 1&this._updateState}performUpdate(){this._instanceProperties&&this._applyInstanceProperties();let t=!1;const e=this._changedProperties;try{t=this.shouldUpdate(e),t?this.update(e):this._markUpdated()}catch(e){throw t=!1,this._markUpdated(),e}t&&(1&this._updateState||(this._updateState=1|this._updateState,this.firstUpdated(e)),this.updated(e))}_markUpdated(){this._changedProperties=new Map,this._updateState=-5&this._updateState}get updateComplete(){return this._getUpdateComplete()}_getUpdateComplete(){return this._updatePromise}shouldUpdate(t){return!0}update(t){void 0!==this._reflectingProperties&&this._reflectingProperties.size>0&&(this._reflectingProperties.forEach((t,e)=>this._propertyToAttribute(e,this[e],t)),this._reflectingProperties=void 0),this._markUpdated()}updated(t){}firstUpdated(t){}}B.finalized=!0;
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */
const J=(t,e)=>"method"===e.kind&&e.descriptor&&!("value"in e.descriptor)?Object.assign(Object.assign({},e),{finisher(n){n.createProperty(e.key,t)}}):{kind:"field",key:Symbol(),placement:"own",descriptor:{},initializer(){"function"==typeof e.initializer&&(this[e.key]=e.initializer.call(this))},finisher(n){n.createProperty(e.key,t)}};function W(t){return(e,n)=>void 0!==n?((t,e,n)=>{e.constructor.createProperty(n,t)})(t,e,n):J(t,e)}
/**
@license
Copyright (c) 2019 The Polymer Project Authors. All rights reserved.
This code may only be used under the BSD style license found at
http://polymer.github.io/LICENSE.txt The complete set of authors may be found at
http://polymer.github.io/AUTHORS.txt The complete set of contributors may be
found at http://polymer.github.io/CONTRIBUTORS.txt Code distributed by Google as
part of the polymer project is also subject to an additional IP rights grant
found at http://polymer.github.io/PATENTS.txt
*/const Z="adoptedStyleSheets"in Document.prototype&&"replace"in CSSStyleSheet.prototype,X=Symbol();class G{constructor(t,e){if(e!==X)throw new Error("CSSResult is not constructable. Use `unsafeCSS` or `css` instead.");this.cssText=t}get styleSheet(){return void 0===this._styleSheet&&(Z?(this._styleSheet=new CSSStyleSheet,this._styleSheet.replaceSync(this.cssText)):this._styleSheet=null),this._styleSheet}toString(){return this.cssText}}const K=(t,...e)=>{const n=e.reduce((e,n,i)=>e+(t=>{if(t instanceof G)return t.cssText;if("number"==typeof t)return t;throw new Error(`Value passed to 'css' function must be a 'css' function result: ${t}. Use 'unsafeCSS' to pass non-literal values, but\n            take care to ensure page security.`)})(n)+t[i+1],t[0]);return new G(n,X)};
/**
 * @license
 * Copyright (c) 2017 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at
 * http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at
 * http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at
 * http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at
 * http://polymer.github.io/PATENTS.txt
 */
(window.litElementVersions||(window.litElementVersions=[])).push("2.3.1");const Q={};class tt extends B{static getStyles(){return this.styles}static _getUniqueStyles(){if(this.hasOwnProperty(JSCompiler_renameProperty("_styles",this)))return;const t=this.getStyles();if(void 0===t)this._styles=[];else if(Array.isArray(t)){const e=(t,n)=>t.reduceRight((t,n)=>Array.isArray(n)?e(n,t):(t.add(n),t),n),n=e(t,new Set),i=[];n.forEach(t=>i.unshift(t)),this._styles=i}else this._styles=[t]}initialize(){super.initialize(),this.constructor._getUniqueStyles(),this.renderRoot=this.createRenderRoot(),window.ShadowRoot&&this.renderRoot instanceof window.ShadowRoot&&this.adoptStyles()}createRenderRoot(){return this.attachShadow({mode:"open"})}adoptStyles(){const t=this.constructor._styles;0!==t.length&&(void 0===window.ShadyCSS||window.ShadyCSS.nativeShadow?Z?this.renderRoot.adoptedStyleSheets=t.map(t=>t.styleSheet):this._needsShimAdoptedStyleSheets=!0:window.ShadyCSS.ScopingShim.prepareAdoptedCssText(t.map(t=>t.cssText),this.localName))}connectedCallback(){super.connectedCallback(),this.hasUpdated&&void 0!==window.ShadyCSS&&window.ShadyCSS.styleElement(this)}update(t){const e=this.render();super.update(t),e!==Q&&this.constructor.render(e,this.renderRoot,{scopeName:this.localName,eventContext:this}),this._needsShimAdoptedStyleSheets&&(this._needsShimAdoptedStyleSheets=!1,this.constructor._styles.forEach(t=>{const e=document.createElement("style");e.textContent=t.cssText,this.renderRoot.appendChild(e)}))}render(){return Q}}tt.finalized=!0,tt.render=(t,e,i)=>{if(!i||"object"!=typeof i||!i.scopeName)throw new Error("The `scopeName` option is required.");const s=i.scopeName,o=V.has(e),r=H&&11===e.nodeType&&!!e.host,a=r&&!z.has(s),c=a?document.createDocumentFragment():e;if(((t,e,i)=>{let s=V.get(e);void 0===s&&(n(e,e.firstChild),V.set(e,s=new P(Object.assign({templateFactory:D},i))),s.appendInto(e)),s.setValue(t),s.commit()})(t,c,Object.assign({templateFactory:j(s)},i)),a){const t=V.get(c);V.delete(c);const i=t.value instanceof y?t.value.template:void 0;L(s,c,i),n(e,e.firstChild),e.appendChild(c),V.set(e,t)}!o&&r&&window.ShadyCSS.styleElement(e.host)};var et={},nt=/d{1,4}|M{1,4}|YY(?:YY)?|S{1,3}|Do|ZZ|([HhMsDm])\1?|[aA]|"[^"]*"|'[^']*'/g,it="[^\\s]+",st=/\[([^]*?)\]/gm,ot=function(){};function rt(t,e){for(var n=[],i=0,s=t.length;i<s;i++)n.push(t[i].substr(0,e));return n}function at(t){return function(e,n,i){var s=i[t].indexOf(n.charAt(0).toUpperCase()+n.substr(1).toLowerCase());~s&&(e.month=s)}}function ct(t,e){for(t=String(t),e=e||2;t.length<e;)t="0"+t;return t}var lt=["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"],dt=["January","February","March","April","May","June","July","August","September","October","November","December"],ht=rt(dt,3),ut=rt(lt,3);et.i18n={dayNamesShort:ut,dayNames:lt,monthNamesShort:ht,monthNames:dt,amPm:["am","pm"],DoFn:function(t){return t+["th","st","nd","rd"][t%10>3?0:(t-t%10!=10)*t%10]}};var pt={D:function(t){return t.getDate()},DD:function(t){return ct(t.getDate())},Do:function(t,e){return e.DoFn(t.getDate())},d:function(t){return t.getDay()},dd:function(t){return ct(t.getDay())},ddd:function(t,e){return e.dayNamesShort[t.getDay()]},dddd:function(t,e){return e.dayNames[t.getDay()]},M:function(t){return t.getMonth()+1},MM:function(t){return ct(t.getMonth()+1)},MMM:function(t,e){return e.monthNamesShort[t.getMonth()]},MMMM:function(t,e){return e.monthNames[t.getMonth()]},YY:function(t){return ct(String(t.getFullYear()),4).substr(2)},YYYY:function(t){return ct(t.getFullYear(),4)},h:function(t){return t.getHours()%12||12},hh:function(t){return ct(t.getHours()%12||12)},H:function(t){return t.getHours()},HH:function(t){return ct(t.getHours())},m:function(t){return t.getMinutes()},mm:function(t){return ct(t.getMinutes())},s:function(t){return t.getSeconds()},ss:function(t){return ct(t.getSeconds())},S:function(t){return Math.round(t.getMilliseconds()/100)},SS:function(t){return ct(Math.round(t.getMilliseconds()/10),2)},SSS:function(t){return ct(t.getMilliseconds(),3)},a:function(t,e){return t.getHours()<12?e.amPm[0]:e.amPm[1]},A:function(t,e){return t.getHours()<12?e.amPm[0].toUpperCase():e.amPm[1].toUpperCase()},ZZ:function(t){var e=t.getTimezoneOffset();return(e>0?"-":"+")+ct(100*Math.floor(Math.abs(e)/60)+Math.abs(e)%60,4)}},mt={D:["\\d\\d?",function(t,e){t.day=e}],Do:["\\d\\d?"+it,function(t,e){t.day=parseInt(e,10)}],M:["\\d\\d?",function(t,e){t.month=e-1}],YY:["\\d\\d?",function(t,e){var n=+(""+(new Date).getFullYear()).substr(0,2);t.year=""+(e>68?n-1:n)+e}],h:["\\d\\d?",function(t,e){t.hour=e}],m:["\\d\\d?",function(t,e){t.minute=e}],s:["\\d\\d?",function(t,e){t.second=e}],YYYY:["\\d{4}",function(t,e){t.year=e}],S:["\\d",function(t,e){t.millisecond=100*e}],SS:["\\d{2}",function(t,e){t.millisecond=10*e}],SSS:["\\d{3}",function(t,e){t.millisecond=e}],d:["\\d\\d?",ot],ddd:[it,ot],MMM:[it,at("monthNamesShort")],MMMM:[it,at("monthNames")],a:[it,function(t,e,n){var i=e.toLowerCase();i===n.amPm[0]?t.isPm=!1:i===n.amPm[1]&&(t.isPm=!0)}],ZZ:["[^\\s]*?[\\+\\-]\\d\\d:?\\d\\d|[^\\s]*?Z",function(t,e){var n,i=(e+"").match(/([+-]|\d\d)/gi);i&&(n=60*i[1]+parseInt(i[2],10),t.timezoneOffset="+"===i[0]?n:-n)}]};mt.dd=mt.d,mt.dddd=mt.ddd,mt.DD=mt.D,mt.mm=mt.m,mt.hh=mt.H=mt.HH=mt.h,mt.MM=mt.M,mt.ss=mt.s,mt.A=mt.a,et.masks={default:"ddd MMM DD YYYY HH:mm:ss",shortDate:"M/D/YY",mediumDate:"MMM D, YYYY",longDate:"MMMM D, YYYY",fullDate:"dddd, MMMM D, YYYY",shortTime:"HH:mm",mediumTime:"HH:mm:ss",longTime:"HH:mm:ss.SSS"},et.format=function(t,e,n){var i=n||et.i18n;if("number"==typeof t&&(t=new Date(t)),"[object Date]"!==Object.prototype.toString.call(t)||isNaN(t.getTime()))throw new Error("Invalid Date in fecha.format");e=et.masks[e]||e||et.masks.default;var s=[];return(e=(e=e.replace(st,(function(t,e){return s.push(e),"@@@"}))).replace(nt,(function(e){return e in pt?pt[e](t,i):e.slice(1,e.length-1)}))).replace(/@@@/g,(function(){return s.shift()}))},et.parse=function(t,e,n){var i=n||et.i18n;if("string"!=typeof e)throw new Error("Invalid format in fecha.parse");if(e=et.masks[e]||e,t.length>1e3)return null;var s={},o=[],r=[];e=e.replace(st,(function(t,e){return r.push(e),"@@@"}));var a,c=(a=e,a.replace(/[|\\{()[^$+*?.-]/g,"\\$&")).replace(nt,(function(t){if(mt[t]){var e=mt[t];return o.push(e[1]),"("+e[0]+")"}return t}));c=c.replace(/@@@/g,(function(){return r.shift()}));var l=t.match(new RegExp(c,"i"));if(!l)return null;for(var d=1;d<l.length;d++)o[d-1](s,l[d],i);var h,u=new Date;return!0===s.isPm&&null!=s.hour&&12!=+s.hour?s.hour=+s.hour+12:!1===s.isPm&&12==+s.hour&&(s.hour=0),null!=s.timezoneOffset?(s.minute=+(s.minute||0)-+s.timezoneOffset,h=new Date(Date.UTC(s.year||u.getFullYear(),s.month||0,s.day||1,s.hour||0,s.minute||0,s.second||0,s.millisecond||0))):h=new Date(s.year||u.getFullYear(),s.month||0,s.day||1,s.hour||0,s.minute||0,s.second||0,s.millisecond||0),h};(function(){try{(new Date).toLocaleDateString("i")}catch(t){return"RangeError"===t.name}})(),function(){try{(new Date).toLocaleString("i")}catch(t){return"RangeError"===t.name}}(),function(){try{(new Date).toLocaleTimeString("i")}catch(t){return"RangeError"===t.name}}();var ft=["closed","locked","off"],gt=function(t,e,n,i){i=i||{},n=null==n?{}:n;var s=new Event(e,{bubbles:void 0===i.bubbles||i.bubbles,cancelable:Boolean(i.cancelable),composed:void 0===i.composed||i.composed});return s.detail=n,t.dispatchEvent(s),s},_t=function(t){gt(window,"haptic",t)},yt=function(t,e,n,i){var s;if("double_tap"===i&&n.double_tap_action?s=n.double_tap_action:"hold"===i&&n.hold_action?s=n.hold_action:"tap"===i&&n.tap_action&&(s=n.tap_action),s||(s={action:"more-info"}),!s.confirmation||s.confirmation.exemptions&&s.confirmation.exemptions.some((function(t){return t.user===e.user.id}))||(_t("warning"),confirm(s.confirmation.text||"Are you sure you want to "+s.action+"?")))switch(s.action){case"more-info":(n.entity||n.camera_image)&&gt(t,"hass-more-info",{entityId:n.entity?n.entity:n.camera_image});break;case"navigate":s.navigation_path&&function(t,e,n){void 0===n&&(n=!1),n?history.replaceState(null,"",e):history.pushState(null,"",e),gt(window,"location-changed",{replace:n})}(0,s.navigation_path);break;case"url":s.url_path&&window.open(s.url_path);break;case"toggle":n.entity&&(function(t,e){(function(t,e,n){void 0===n&&(n=!0);var i,s=function(t){return t.substr(0,t.indexOf("."))}(e),o="group"===s?"homeassistant":s;switch(s){case"lock":i=n?"unlock":"lock";break;case"cover":i=n?"open_cover":"close_cover";break;default:i=n?"turn_on":"turn_off"}t.callService(o,i,{entity_id:e})})(t,e,ft.includes(t.states[e].state))}(e,n.entity),_t("success"));break;case"call-service":if(!s.service)return void _t("failure");var o=s.service.split(".",2);e.callService(o[0],o[1],s.service_data),_t("success")}};function vt(t){return void 0!==t&&"none"!==t.action}const wt="ontouchstart"in window||navigator.maxTouchPoints>0||navigator.msMaxTouchPoints>0;class bt extends HTMLElement{constructor(){super(),this.holdTime=500,this.ripple=document.createElement("mwc-ripple"),this.timer=void 0,this.held=!1,this.cooldownStart=!1,this.cooldownEnd=!1}connectedCallback(){Object.assign(this.style,{position:"absolute",width:wt?"100px":"50px",height:wt?"100px":"50px",transform:"translate(-50%, -50%)",pointerEvents:"none"}),this.appendChild(this.ripple),this.ripple.primary=!0,["touchcancel","mouseout","mouseup","touchmove","mousewheel","wheel","scroll"].forEach(t=>{document.addEventListener(t,()=>{clearTimeout(this.timer),this.stopAnimation(),this.timer=void 0},{passive:!0})})}bind(t,e){if(t.actionHandler)return;t.actionHandler=!0,t.addEventListener("contextmenu",t=>{const e=t||window.event;e.preventDefault&&e.preventDefault(),e.stopPropagation&&e.stopPropagation(),e.cancelBubble=!0,e.returnValue=!1});const n=t=>{if(this.cooldownStart)return;let e,n;this.held=!1,t.touches?(e=t.touches[0].pageX,n=t.touches[0].pageY):(e=t.pageX,n=t.pageY),this.timer=window.setTimeout(()=>{this.startAnimation(e,n),this.held=!0},this.holdTime),this.cooldownStart=!0,window.setTimeout(()=>this.cooldownStart=!1,100)},i=n=>{this.cooldownEnd||["touchend","touchcancel"].includes(n.type)&&void 0===this.timer||(clearTimeout(this.timer),this.stopAnimation(),this.timer=void 0,this.held?gt(t,"action",{action:"hold"}):e.hasDoubleTap?1===n.detail||"keyup"===n.type?this.dblClickTimeout=window.setTimeout(()=>{gt(t,"action",{action:"tap"})},250):(clearTimeout(this.dblClickTimeout),gt(t,"action",{action:"double_tap"})):gt(t,"action",{action:"tap"}),this.cooldownEnd=!0,window.setTimeout(()=>this.cooldownEnd=!1,100))};t.addEventListener("touchstart",n,{passive:!0}),t.addEventListener("touchend",i),t.addEventListener("touchcancel",i),t.addEventListener("keyup",t=>{if(13===t.keyCode)return i(t)}),/iPhone OS 13_/.test(window.navigator.userAgent)||(t.addEventListener("mousedown",n,{passive:!0}),t.addEventListener("click",i))}startAnimation(t,e){Object.assign(this.style,{left:t+"px",top:e+"px",display:null}),this.ripple.disabled=!1,this.ripple.active=!0,this.ripple.unbounded=!0}stopAnimation(){this.ripple.active=!1,this.ripple.disabled=!0,this.style.display="none"}}customElements.define("action-handler-button-text-card",bt);const St=(t,e)=>{const n=(()=>{const t=document.body;if(t.querySelector("action-handler-button-text-card"))return t.querySelector("action-handler-button-text-card");const e=document.createElement("action-handler-button-text-card");return t.appendChild(e),e})();n&&n.bind(t,e)},xt=(t=>(...e)=>{const n=t(...e);return m.set(n,!0),n})((t={})=>e=>{St(e.committer.element,t)});var Ct;console.info("%c  BUTTON-TEXT-CARD \n%c  v0.5.7    ","color: orange; font-weight: bold; background: black","color: white; font-weight: bold; background: dimgray");let Pt=Ct=class extends tt{constructor(){super(...arguments),this._hasTemplate=!1}setConfig(t){if(!t||t.show_error)throw new Error("Invalid configuration.");this._config=Object.assign({name:"Button Text Card",title:"",subtitle:"",large:!1},t),this._renderedConfig=Object.assign({},this._config);for(const t of Ct.templateFields){const e=Ct.templateRegex.exec(this._config[t]);if(Ct.templateRegex.lastIndex=0,null!==e){this._hasTemplate=!0;break}}}shouldUpdate(t){var e;return!(null===(e=this._config)||void 0===e?void 0:e.entity)||function(t,e,n){if(e.has("config")||n)return!0;if(t._config.entity){var i=e.get("hass");return!i||i.states[t._config.entity]!==t.hass.states[t._config.entity]}return!1}(this,t,this._hasTemplate)}evaluateJsTemplates(){if(this._renderedConfig&&this._config)for(const t of Ct.templateFields){const e=Ct.templateRegex.exec(this._config[t]);Ct.templateRegex.lastIndex=0,e&&e.length>1?this._renderedConfig[t]=this._evalTemplate(this._stateObj,e[1]):this._renderedConfig[t]=this._config[t]}}render(){if(!this._config||!this.hass||!this._renderedConfig)return Y``;if(this._stateObj=this._config.entity?this.hass.states[this._config.entity]:void 0,this.evaluateJsTemplates(),!this._inEditMode()&&!0===this._renderedConfig.hide_condition)return Y``;if(!this._config.icon||""===this._config.icon){let t="mdi:alert-circle";if(this._config.entity){const e=this.hass.states[this._config.entity].attributes.icon;e&&(t=e)}this.setConfig(Object.assign(Object.assign({},this._config),{icon:t}))}return this._renderedConfig.background_color&&this.style.setProperty("--ha-card-background",this._renderedConfig.background_color),this._renderedConfig.font_color&&this.style.setProperty("--primary-text-color",this._renderedConfig.font_color),this._renderedConfig.icon_size&&this.style.setProperty("--mdc-icon-size",this._renderedConfig.icon_size+"px"),this._configureIconColor(),Y`
      <ha-card
        @action=${this._handleAction}
        .actionHandler=${xt({hasHold:vt(this._config.hold_action),hasDoubleTap:vt(this._config.double_tap_action),repeat:this._config.hold_action?this._config.hold_action.repeat:void 0})}
        class="${this._inEditMode()&&!0===this._renderedConfig.hide_condition?"edit-preview":""}"
        tabindex="0"
      >
        <div class="flex-container ${!0===this._renderedConfig.large?"card-look":""}">
          <div class="icon-container ${!1===this._renderedConfig.large?"card-look":""}">
            <ha-icon
              icon="${this._renderedConfig.icon}"
              class="${"spin"===this._renderedConfig.icon_animation?"spin":""}"
            ></ha-icon>
          </div>

          ${""===this._renderedConfig.title&&""===this._renderedConfig.subtitle?Y``:Y`
                <div class="text-container">
                  <h1>${this._renderedConfig.title}</h1>
                  <p class="${""===this._renderedConfig.subtitle?"hidden":""}">
                    ${this._renderedConfig.subtitle}
                  </p>
                </div>
              `}
        </div>
      </ha-card>
    `}_handleAction(t){this.hass&&this._config&&t.detail.action&&yt(this,this.hass,this._config,t.detail.action)}_configureIconColor(){var t,e,n,i,s;(null===(t=this._renderedConfig)||void 0===t?void 0:t.icon_color)&&"auto"!==this._renderedConfig.icon_color?this.style.setProperty("--icon-color",this._renderedConfig.icon_color):"auto"!==(null===(e=this._renderedConfig)||void 0===e?void 0:e.icon_color)||"on"!==(null===(n=this._stateObj)||void 0===n?void 0:n.state)?(null===(i=this._renderedConfig)||void 0===i?void 0:i.icon_color)||!(null===(s=this._renderedConfig)||void 0===s?void 0:s.font_color)?this.style.setProperty("--icon-color","var(--primary-text-color)"):this.style.setProperty("--icon-color",this._renderedConfig.font_color):this.style.setProperty("--icon-color","var(--paper-item-icon-active-color)")}_inEditMode(){var t,e,n,i,s,o,r,a;const c=null===(a=null===(r=null===(o=null===(s=null===(i=null===(n=null===(e=null===(t=document.querySelector("home-assistant"))||void 0===t?void 0:t.shadowRoot)||void 0===e?void 0:e.querySelector("home-assistant-main"))||void 0===n?void 0:n.shadowRoot)||void 0===i?void 0:i.querySelector("app-drawer-layout partial-panel-resolver ha-panel-lovelace"))||void 0===s?void 0:s.shadowRoot)||void 0===o?void 0:o.querySelector("hui-root"))||void 0===r?void 0:r.shadowRoot)||void 0===a?void 0:a.querySelector("ha-app-layout app-header app-toolbar");return!!c&&c.classList.contains("edit-mode")}_evalTemplate(t,e){return this.hass?new Function("states","entity","user","hass","variables","'use strict'; "+e).call(this,this.hass.states,t,this.hass.user,this.hass,[]):""}static get styles(){return K`
      @-moz-keyframes spin {
        100% {
          -moz-transform: rotate(360deg);
        }
      }
      @-webkit-keyframes spin {
        100% {
          -webkit-transform: rotate(360deg);
        }
      }
      @keyframes spin {
        100% {
          -webkit-transform: rotate(360deg);
          transform: rotate(360deg);
        }
      }

      ha-card {
        background-color: rgba(255, 255, 255, 0);
        box-shadow: 2px 2px rgba(0, 0, 0, 0);
        padding: 16px;
        outline: none;
      }

      ha-card.edit-preview {
        opacity: 0.5;
      }

      .warning {
        display: block;
        color: black;
        background-color: #fce588;
        padding: 8px;
      }

      .flex-container {
        width: 100%;
        display: flex;
        align-items: center;
        color: rgb(99, 107, 116);
      }

      .card-look {
        border-radius: 16px;
        background: var(--ha-card-background, var(--card-background-color, white));
        box-shadow: var(--ha-card-box-shadow, 9px 9px 17px rgba(0, 0, 0, 0.14), -9px -9px 17px rgba(0, 0, 0, 0.12));
      }

      .icon-container {
        width: 85px;
        height: 85px;
        display: flex;
        align-items: center;
        justify-content: center;
        text-align: center;
      }

      .text-container {
        color: var(--primary-text-color);
        margin-left: 24px;
      }

      .icon-container ha-icon {
        color: var(--icon-color);
      }

      .icon-container ha-icon.spin {
        -webkit-animation: spin 4s linear infinite;
        -moz-animation: spin 4s linear infinite;
        animation: spin 4s linear infinite;
      }

      .text-container {
        flex: 1;
      }
      .text-container h1 {
        font-size: 21px;
        font-weight: 500;
        margin: 0;
      }
      .text-container h1 + p {
        margin-top: 10px;
      }
      .text-container p {
        font-size: 15px;
        font-weight: 400;
        margin: 0;
      }

      .text-container p.hidden {
        display: none;
      }
    `}};var Tt;Pt.templateFields=["title","subtitle","icon","icon_size","hide_condition","font_color","background_color","shadow_color","large","spin","icon_color"],Pt.templateRegex=new RegExp("\\[\\[\\[([^]*)\\]\\]\\]","gm"),t([W()],Pt.prototype,"hass",void 0),t([W()],Pt.prototype,"_config",void 0),t([W()],Pt.prototype,"_hasTemplate",void 0),t([W()],Pt.prototype,"_stateObj",void 0),Pt=Ct=t([(Tt="button-text-card",t=>"function"==typeof t?((t,e)=>(window.customElements.define(t,e),e))(Tt,t):((t,e)=>{const{kind:n,elements:i}=e;return{kind:n,elements:i,finisher(e){window.customElements.define(t,e)}}})(Tt,t))],Pt);export{Pt as BoilerplateCard};
//# sourceMappingURL=button-text-card.js.map
