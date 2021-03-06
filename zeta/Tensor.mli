module type Tensor =
  sig
    
  type op = 
    | IntOp : (int -> int) -> op  
    | BoolOp : (bool -> bool) -> op
    | FloatOp : (float -> float) -> op

  type predicate = 
    | IntP : (int -> bool) -> predicate  
    | BoolP : (bool -> bool) -> predicate
    | FloatP : (float -> bool) -> predicate

  type 'a tensordata = 
      | IntScalar : int ref -> int tensordata
      | FloatScalar : float ref -> float tensordata
      | BoolScalar : bool ref -> bool tensordata
      | IntTensor : int tensordata array -> int tensordata
      | FloatTensor : float tensordata array -> float tensordata
      | BoolTensor : bool tensordata array  -> bool tensordata
      
  type shape = int array
  type index = int array

  (* Next Layer *)
  (* Gradient : RetainRequire for freshly constructed graphs and tensors that don't require gradient
                 and Grad for backpropped graphs
                bool used to encode retrain_grad option
   *)
  (* Directed Acyclic Graph (DAG) for tensor operations: 
      Null for "isolated" tensors that do not belong to any graph
      Graph for tensors as nodes in the graph - 
          gradient, node it's connected to with associated operations and node that connects to it
  *)
  type 'a grad_fn = End | Fn of ('a tensor * op) array
  and 'a gradient = Retain of bool | Grad of (bool * 'a tensordata)
  and 'a parent = 'a tensor array
  and 'a node = LeafNoGrad | LeafGrad of 'a gradient | Node of ('a parent * 'a gradient)
  and 'a directed_acyclic_graph = Null | Graph of ('a grad_fn * 'a node)
  (* shape describes the dimensions of the data *)
  and 'a tensor = (shape * 'a tensordata * 'a directed_acyclic_graph ) ref  
  
  exception TypeMismatch of string
  exception TensorInvariantViolated
  exception ShapeMismatch of string
  exception IndexError of string
  exception ZeroDimension
  exception AutogradError of string

  val new_bool : shape -> bool -> bool tensor
  val new_int : shape -> int -> int tensor
  val new_float : shape -> float -> float tensor
  val copy : 'a tensor -> 'a tensor
  
  val new_t : shape -> 'a tensor -> bool -> 'a tensor
  val broadcast : 'a tensor -> shape -> bool -> 'a tensor

  val reduce : predicate -> (bool * bool -> bool) -> bool -> 'a tensordata -> bool 
  val any : predicate -> 'a tensor -> bool
  val all : predicate -> 'a tensor -> bool

  val apply : op -> 'a tensor -> unit
  
  val get : 'a tensor -> index -> 'a
  val set : 'a tensor -> index -> 'a -> unit

  val abs : 'a tensor -> unit
  val sigmoid : 'a tensor -> unit

  end 
