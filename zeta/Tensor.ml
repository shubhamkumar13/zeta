module Tensor =
  struct

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
      | Null
      
  type shape = int array
  type index = int array

  type 'a grad_fn = 
    | Empty : 'a grad_fn 
    | Fn : ('a tensor * op) array -> 'a grad_fn
  and 'a tensor = (shape * 'a tensordata * 'a tensordata * 'a grad_fn) ref  
  
  exception TypeMismatch of string
  exception TensorInvariantViolated
  exception NullTensor
  exception ShapeMismatch of string
  exception IndexError of string
  exception ZeroDimension

  let rec _reduce_int (f : int -> bool) (g : bool * bool -> bool) 
                      (v : bool) (t : int tensordata) : bool = 
    match t with
    | IntScalar e -> f (!e)
    | IntTensor ts -> Array.fold_left (fun b p -> g (b,(_reduce_int f g v p))) v ts
    | _ -> raise TensorInvariantViolated

  let rec _reduce_float (f : float -> bool) (g : bool * bool -> bool) 
                      (v : bool) (t : float tensordata) : bool = 
    match t with
    | FloatScalar e -> f (!e)
    | FloatTensor ts -> Array.fold_left (fun b p -> g (b,(_reduce_float f g v p))) v ts
    | _ -> raise TensorInvariantViolated

  let rec _reduce_bool (f : bool -> bool) (g : bool * bool -> bool) 
                      (v : bool) (t : bool tensordata) : bool = 
    match t with
    | BoolScalar e -> f (!e)
    | BoolTensor ts -> Array.fold_left (fun b p -> g (b,(_reduce_bool f g v p))) v ts
    | _ -> raise TensorInvariantViolated

  let reduce (type el) (f : predicate) (g : bool * bool -> bool) 
                        (v : bool) (t : el tensordata) : bool =
    match (f, t) with
    | (_, Null) -> raise NullTensor
    | (BoolP f', BoolScalar e) -> f' (!e)
    | (BoolP f', BoolTensor e) -> _reduce_bool f' g v (BoolTensor e)
    | (IntP f', IntScalar e) -> f' (!e)
    | (IntP f', IntTensor e) -> _reduce_int f' g v (IntTensor e)
    | (FloatP f', FloatScalar e) -> f' (!e)
    | (FloatP f', FloatTensor e) -> _reduce_float f' g v (FloatTensor e)
    | (IntP _, FloatScalar _) -> raise (TypeMismatch "Attempted to apply int predicate on FloatScalar")
    | (IntP _, BoolScalar _) -> raise (TypeMismatch "Attempted to apply int predicate on BoolScalar")
    | (BoolP _, FloatScalar _) -> raise (TypeMismatch "Attempted to apply bool predicate on FloatScalar")
    | (BoolP _, IntScalar _) -> raise (TypeMismatch "Attempted to apply bool predicate on IntScalar")
    | (IntP _, FloatTensor _) -> raise (TypeMismatch "Attempted to apply int predicate on FloatTensor")
    | (IntP _, BoolTensor _) -> raise (TypeMismatch "Attempted to apply int predicate on BoolTensor")
    | (BoolP _, FloatTensor _) -> raise (TypeMismatch "Attempted to apply bool predicate on FloatTensor")
    | (BoolP _, IntTensor _) -> raise (TypeMismatch "Attempted to apply bool predicate on IntTensor")
    | (FloatP _, IntScalar _) -> raise (TypeMismatch "Attempted to apply float predicate on IntScalar")
    | (FloatP _, IntTensor _) -> raise (TypeMismatch "Attempted to apply float predicate on IntTensor")
    | (FloatP _, BoolScalar _) -> raise (TypeMismatch "Attempted to apply float predicate on BoolScalar")
    | (FloatP _, BoolTensor _) -> raise (TypeMismatch "Attempted to apply float predicate on BoolTensor")

  let all f (t : 'a tensor) = let (shape, data, grad, grad_fn) = !t in reduce f (fun (x,y) -> x && y) true data
  let any f (t : 'a tensor) = let (shape, data, grad, grad_fn) = !t in reduce f (fun (x,y) -> x || y) false data

  let rec _apply_int f (t : int tensordata) : unit = 
    match t with
    | IntScalar e -> e := (f (!e))
    | IntTensor ts -> (ignore (Array.map (fun e -> _apply_int f e) ts) ; ())
    | _ -> raise TensorInvariantViolated

  let rec _apply_float f (t : float tensordata) : unit = 
    match t with
    | FloatScalar e -> e := (f (!e))
    | FloatTensor ts -> (ignore (Array.map (fun e -> _apply_float f e) ts) ; ())
    | _ -> raise TensorInvariantViolated

  let rec _apply_bool f (t : bool tensordata) : unit = 
    match t with
    | BoolScalar e -> e := (f (!e))
    | BoolTensor ts -> (ignore (Array.map (fun e -> _apply_bool f e) ts) ; ())
    | _ -> raise TensorInvariantViolated

  let _apply (type el) (f : op) (t : el tensordata) : unit =
    match (f, t) with
    | (_, Null) -> raise NullTensor
    | (BoolOp f', BoolScalar e) -> e := (f' (!e))
    | (BoolOp f', BoolTensor e) -> _apply_bool f' (BoolTensor e)
    | (IntOp f', IntScalar e) -> e := (f' (!e))
    | (IntOp f', IntTensor e) -> _apply_int f' (IntTensor e)
    | (FloatOp f', FloatScalar e) -> e := (f' (!e))
    | (FloatOp f', FloatTensor e) -> _apply_float f' (FloatTensor e)
    | (IntOp _, FloatScalar _) -> raise (TypeMismatch "Attempted to apply int function on FloatScalar")
    | (IntOp _, BoolScalar _) -> raise (TypeMismatch "Attempted to apply int function on BoolScalar")
    | (BoolOp _, FloatScalar _) -> raise (TypeMismatch "Attempted to apply bool function on FloatScalar")
    | (BoolOp _, IntScalar _) -> raise (TypeMismatch "Attempted to apply bool function on IntScalar")
    | (IntOp _, FloatTensor _) -> raise (TypeMismatch "Attempted to apply int function on FloatTensor")
    | (IntOp _, BoolTensor _) -> raise (TypeMismatch "Attempted to apply int function on BoolTensor")
    | (BoolOp _, FloatTensor _) -> raise (TypeMismatch "Attempted to apply bool function on FloatTensor")
    | (BoolOp _, IntTensor _) -> raise (TypeMismatch "Attempted to apply bool function on IntTensor")
    | (FloatOp _, IntScalar _) -> raise (TypeMismatch "Attempted to apply float function on IntScalar")
    | (FloatOp _, IntTensor _) -> raise (TypeMismatch "Attempted to apply float function on IntTensor")
    | (FloatOp _, BoolScalar _) -> raise (TypeMismatch "Attempted to apply float function on BoolScalar")
    | (FloatOp _, BoolTensor _) -> raise (TypeMismatch "Attempted to apply float function on BoolTensor")

  let apply f (t : 'a tensor) = let (shape, data, grad, grad_fn) = !t in _apply f data
  
  let _abs (type el) (t : el tensordata) : unit =
    let absf v = if v > 0.0 then v else v *. (-1.0) in
    let absi v = if v > 0 then v else v * (-1) in
    let absb _ = true in
    match t with
    | BoolScalar e -> _apply (BoolOp absb) (BoolScalar e)
    | BoolTensor e -> _apply (BoolOp absb) (BoolTensor e)
    | IntScalar e -> _apply (IntOp absi) (IntScalar e)
    | IntTensor e -> _apply (IntOp absi) (IntTensor e)
    | FloatScalar e -> _apply (FloatOp absf) (FloatScalar e)
    | FloatTensor e -> _apply (FloatOp absf) (FloatTensor e)
    | Null -> raise NullTensor
  
  let abs (t : 'a tensor) = let (shape, data, grad, grad_fn) = !t in _abs data

  let sigmoid (t : 'a tensor) = apply (FloatOp (fun x -> Float.exp(x) /. (Float.exp(x) +. 1.0))) t
  
  let _check_valid_shape shape =
    let len = Array.length shape in
    if (Array.fold_left (fun x y -> x || y) false (Array.init len (fun i -> (Array.get shape i)<0)) ) then raise (IndexError "Negative size along one of the dimensions")
    else if (Array.fold_left (fun x y -> x || y) false (Array.init len (fun i -> (Array.get shape i)=0)) )
    then (Printf.printf "Warning : one of the dimensions is zero. \n"; raise ZeroDimension)
    else ()

    
  let _copy (type el) (e : el tensordata) (b : bool) : el tensordata = 
    let rec _copy_bool (t : bool tensordata)=
      match t with
      | BoolScalar r ->  BoolScalar (ref (!r))
      | BoolTensor r -> BoolTensor (Array.map (fun i -> _copy_bool i) r)
      | _ -> raise TensorInvariantViolated 
    in
    let rec _copy_int (t : int tensordata) =
      match t with
      | IntScalar r -> IntScalar (ref (!r))
      | IntTensor r -> IntTensor (Array.map (fun i -> _copy_int i) r)
      | _ -> raise TensorInvariantViolated 
    in
    let rec _copy_float (t : float tensordata)=
      match t with
      | FloatScalar r -> FloatScalar (ref (!r))
      | FloatTensor r -> FloatTensor (Array.map (fun i -> _copy_float i) r)
      | _ -> raise TensorInvariantViolated 
    in
    if b then match e with
    | IntScalar r -> IntScalar (ref (!r))
    | FloatScalar r -> FloatScalar (ref (!r))
    | BoolScalar r -> BoolScalar (ref (!r))
    | BoolTensor r -> BoolTensor (Array.map (fun i -> _copy_bool i) r)
    | FloatTensor r -> FloatTensor (Array.map (fun i -> _copy_float i) r)
    | IntTensor r -> IntTensor (Array.map (fun i -> _copy_int i) r)
    | Null -> Null
     else e
    
  let copy t = let (shape, data, grad, grad_fn) = !t in
    ref (shape, _copy data true, _copy grad true, grad_fn)

  let rec _new_bool (s : int list) v b = match s with
    | [] -> _copy v b
    | [e] -> BoolTensor (Array.init e (fun i -> _copy v b))
    | e::s' -> BoolTensor (Array.init e (fun i -> _new_bool s' v b))

  let new_bool (s : shape) v = 
    let s' = Array.to_list s in
    let v' = BoolScalar (ref v) in
    try (_check_valid_shape s; (ref (s, _new_bool s' v' true, Null, Empty) : bool tensor))
    with ZeroDimension -> (ref (s, BoolTensor [||], Null, Empty))

  let rec _new_int (s : int list) v b = match s with
    | [] -> _copy v b
    | [e] -> IntTensor (Array.init e (fun i -> _copy v b))
    | e::s' -> IntTensor (Array.init e (fun i -> _new_int s' v b))

  let new_int (s : shape) v = 
    let s' = Array.to_list s in
    let v' = IntScalar (ref v) in
    try (_check_valid_shape s; (ref (s, _new_int s' v' true, Null, Empty) : int tensor))
    with ZeroDimension -> (ref (s, IntTensor [||], Null, Empty))


  let rec _new_float (s : int list) v b = match s with
    | [] -> _copy v b
    | [e] -> FloatTensor (Array.init e (fun i -> _copy v b))
    | e::s' -> FloatTensor (Array.init e (fun i -> _new_float s' v b))

  let new_float (s : shape) v = 
    let s' = Array.to_list s in
    let v' = FloatScalar (ref v) in
    try (_check_valid_shape s; (ref (s, _new_float s' v' true, Null, Empty) : float tensor))
    with ZeroDimension -> (ref (s, FloatTensor [||], Null, Empty))


  let rec _new_t (type el) (s : int list) (v : el tensordata) b : el tensordata = 
    let f t b = if b then ref (!t) else t in
    match (s,v) with
    | ([], IntScalar t) -> IntScalar (f t b)
    | (e::s', IntScalar t) -> _new_int (e::s') (IntScalar t) b
    | ([], IntTensor t) -> _copy (IntTensor t) b
    | (e::s', IntTensor t) -> _new_int (e::s') (IntTensor t) b
    | ([], FloatTensor t) -> _copy (FloatTensor t) b
    | (e::s', FloatTensor t) -> _new_float (e::s') (FloatTensor t) b
    | ([], FloatScalar t) -> FloatScalar (f t b)
    | (e::s', FloatScalar t) -> _new_float (e::s') (FloatScalar t) b
    | ([], BoolScalar t) -> BoolScalar (f t b)
    | (e::s', BoolScalar t) -> _new_bool (e::s') (BoolScalar t) b
    | ([], BoolTensor t) -> _copy (BoolTensor t) b
    | (e::s', BoolTensor t) -> _new_bool (e::s') (BoolTensor t) b
    | (_, Null) -> raise NullTensor

  let new_t (type el) (s : shape) (t : el tensor) b = 
    let s' = (Array.to_list s) in
    let (shape, data, grad, grad_fn) = !t in
    let news = Array.of_list( List.append s' (Array.to_list shape) ) in
    let newgrad = try (_new_t s' grad b) with NullTensor -> Null in 
    let newt = 
    try (_check_valid_shape s; (news, _new_t s' data b, newgrad , grad_fn))
    with ZeroDimension -> match data with
      | IntScalar _ ->  (s, IntTensor [||], IntTensor [||], grad_fn)
      | IntTensor _ ->  (s, IntTensor [||], IntTensor [||], grad_fn)
      | FloatScalar _ ->  (s, FloatTensor [||], FloatTensor [||], grad_fn)
      | FloatTensor _ ->  (s, FloatTensor [||], FloatTensor [||], grad_fn)
      | BoolScalar _ ->  (s, BoolTensor [||], BoolTensor [||], grad_fn)
      | BoolTensor _ ->  (s, BoolTensor [||], BoolTensor [||], grad_fn)
      | Null -> ( (s, Null, Null, grad_fn))
    in
    if b then ref newt else (t := newt; t)

  let rec _getset_float (t : 'a tensordata) idx f = 
    match (t, idx) with
    | (FloatScalar r, []) -> f r
    | (FloatTensor r, e::s') -> _getset_float (Array.get r e) s' f
    | _ -> raise TensorInvariantViolated

  let rec _getset_int (t : 'a tensordata) idx f = 
    match (t, idx) with
    | (IntScalar r, []) -> f r
    | (IntTensor r, e::s') -> _getset_int (Array.get r e) s' f
    | _ -> raise TensorInvariantViolated

  let rec _getset_bool (t : 'a tensordata) idx f = 
    match (t, idx) with
    | (BoolScalar r, []) -> f r
    | (BoolTensor r, e::s') -> _getset_bool (Array.get r e) s' f
    | _ -> raise TensorInvariantViolated

  let _getset (type el) (t : el tensordata) idx (f : el ref -> 'a) = 
    match (t, idx) with
    | (FloatScalar r, []) -> f r
    | (FloatTensor r, e::s') -> _getset_float (FloatTensor r) (e::s') f
    | (IntScalar r, []) -> f r
    | (IntTensor r, e::s') -> _getset_int (IntTensor r) (e::s') f
    | (BoolScalar r, []) -> f r
    | (BoolTensor r, e::s') -> _getset_bool (BoolTensor r) (e::s') f
    | _ -> raise TensorInvariantViolated
    
  let _check_valid_idx (data, shape, idx) =
    match data with | Null -> raise NullTensor | _ -> 
    let len1 = Array.length shape in
    let len2 = Array.length idx in
    if (len1) != (len2) then raise (IndexError (("Expected index of length "^(string_of_int len1))^("; Got "^(string_of_int len2)) ) )
    else if idx < Array.init len1 (fun x -> 0) then raise (IndexError "Negative indexing not supported")
    else if not (Array.fold_left (fun x y -> x && y) true (Array.init len1 (fun i -> (Array.get idx i) < (Array.get shape i))) )
    then raise (IndexError "Array index out of bound")
    else ()

  let set (t : 'a tensor) idx e = let (shape, data, grad, grad_fn) = !t in
    (_check_valid_idx (data, shape, idx) ; _getset data (Array.to_list idx) (fun x -> x := e))

  let get (t : 'a tensor) idx = let (shape, data, grad, grad_fn) = !t in
    (_check_valid_idx (data, shape, idx) ; _getset data (Array.to_list idx) (fun x -> !x))

  (* dangerous *)
  let _set t idx e = _getset t (Array.to_list idx) (fun x -> x := e)
  
  let _check_broadcastable s d =
    let (source, destination) = ((List.rev (Array.to_list s)), (List.rev (Array.to_list d))) in
    let rec _check_broadcastable' source destination = 
      match (source, destination) with
        | ([], d) -> (destination, [])
        | (_ :: _,[]) -> raise (ShapeMismatch "source array has more dimensions than desired shape")
        | (s :: s', d :: d') -> 
          if s != d && s != 1 then raise (ShapeMismatch "one of the trailing dimensions don't agree")
          else let (lead, trail) = _check_broadcastable' s' d' in (lead, d::trail) in
    let (s', d') = _check_broadcastable' source destination in
      (List.rev s', List.rev d')

  let rec _map_int t source target copy = 
    match (t, source, target) with
    | (IntScalar r, [], []) -> if copy then IntScalar (ref (!r)) else IntScalar r
    | (IntTensor r, e::e', d::d') -> 
        if e = d then 
          IntTensor (Array.map (fun i -> _map_int i e' d' copy) r)
        else
          IntTensor (Array.init d (fun _ -> _map_int (Array.get r 0) e' d' copy))
    | (IntTensor r, [], []) -> IntTensor r
    | _ -> raise TensorInvariantViolated

  let rec _map_float t source target copy = 
    match (t, source, target) with
    | (FloatScalar r, [], []) -> if copy then FloatScalar (ref (!r)) else FloatScalar r
    | (FloatTensor r, e::e', d::d') -> 
        if e = d then 
          FloatTensor (Array.map (fun i -> _map_float i e' d' copy) r)
        else
          FloatTensor (Array.init d (fun _ -> _map_float (Array.get r 0) e' d' copy))
    | (FloatTensor r, [], []) -> FloatTensor r
    | _ -> raise TensorInvariantViolated

  let rec _map_bool t source target copy = 
    match (t, source, target) with
    | (BoolScalar r, [], []) -> if copy then BoolScalar (ref (!r)) else BoolScalar r
    | (BoolTensor r, e::e', d::d') -> 
        if e = d then 
          BoolTensor (Array.map (fun i -> _map_bool i e' d' copy) r)
        else
          BoolTensor (Array.init d (fun _ -> _map_bool (Array.get r 0) e' d' copy))
    | (BoolTensor r, [], []) -> BoolTensor r
    | _ -> raise TensorInvariantViolated

  
  let _broadcast (type el) (t : el tensordata) 
                 (source : int list) (lead : int list)
                 (trail : int list) (copy : bool) : el tensordata =  
    let f t b = if b then ref (!t) else t in
    match t with
    | FloatTensor r -> _new_float lead (_map_float (FloatTensor r) source trail copy) copy
    | BoolTensor r -> _new_bool lead (_map_bool (BoolTensor r) source trail copy) copy
    | IntTensor r -> _new_int lead (_map_int (IntTensor r) source trail copy) copy
    | IntScalar r -> _new_int lead (IntScalar (f r copy)) copy
    | FloatScalar r -> _new_float lead (FloatScalar (f r copy)) copy
    | BoolScalar r -> _new_bool lead (BoolScalar (f r copy)) copy
    | _ -> raise TensorInvariantViolated

  let broadcast t destination copy = let (source, data, grad, grad_fn) = !t in
    let (lead_dim, trail_dim) = _check_broadcastable source destination in
    let newdata = _broadcast data (Array.to_list source) lead_dim trail_dim copy in
    let news = Array.of_list (lead_dim @ trail_dim) in
    if copy then ref (news, newdata, grad, grad_fn) else (t := (news, newdata, grad, grad_fn); t)

  let _elem_mul (type el) (t1 : el tensordata) (t2 : el tensordata) = 
    let rec _elem_mul_float t1 t2 =
      match (t1, t2) with
      | (FloatScalar s, FloatScalar s') -> s := (!s *. !s')
      | (FloatTensor t, FloatTensor t') -> (ignore (Array.mapi (fun i e -> _elem_mul_float (Array.get t i) e) t'); ())
      | _ -> raise TensorInvariantViolated
      in  
    let rec _elem_mul_int t1 t2 =
      match (t1, t2) with
      | (IntScalar s, IntScalar s') -> s := (!s * !s')
      | (IntTensor t, IntTensor t') -> (ignore (Array.mapi (fun i e -> _elem_mul_int (Array.get t i) e) t'); ())
      | _ -> raise TensorInvariantViolated
      in  
    let rec _elem_mul_bool t1 t2 =
      match (t1, t2) with
      | (BoolScalar s, BoolScalar s') -> s := (!s && !s')
      | (BoolTensor t, BoolTensor t') -> (ignore (Array.mapi (fun i e -> _elem_mul_bool (Array.get t i) e) t'); ())
      | _ -> raise TensorInvariantViolated
      in  
    match (t1, t2) with
    | (Null, _) -> raise NullTensor
    | (_, Null) -> raise NullTensor
    | (BoolScalar s, BoolScalar s') -> s := (!s && !s')
    | (BoolScalar s, BoolTensor t) -> if !s then () else _apply (BoolOp (fun _ -> false)) (BoolTensor t)
    | (BoolTensor t, BoolScalar s) -> if !s then () else _apply (BoolOp (fun _ -> false)) (BoolTensor t)
    | (IntScalar s, IntScalar s') -> s := (!s * !s')
    | (IntScalar s, IntTensor t) -> _apply (IntOp (fun i -> !s * i)) (IntTensor t)
    | (IntTensor t, IntScalar s) -> _apply (IntOp (fun i -> !s * i)) (IntTensor t)
    | (FloatScalar s, FloatScalar s') -> s := (!s *. !s')
    | (FloatScalar s, FloatTensor t) -> _apply (FloatOp (fun i -> !s *. i)) (FloatTensor t)
    | (FloatTensor t, FloatScalar s) -> _apply (FloatOp (fun i -> !s *. i)) (FloatTensor t)
    | (FloatTensor t, FloatTensor t') -> _elem_mul_float (FloatTensor t) (FloatTensor t')
    | (IntTensor t, IntTensor t') -> _elem_mul_int (IntTensor t) (IntTensor t')
    | (BoolTensor t, BoolTensor t') -> _elem_mul_bool (BoolTensor t) (BoolTensor t')
    | (_, _) -> raise (TypeMismatch "you can only multiply tensors of the same kind")
  
  let (#*) (t1 : 'a tensor) (t2 : 'a tensor) : 'a tensor = 
    let ((s1, d1, g1, r1),(s2, d2, g2, r2)) = (!t1, !t2) in
    let max_dim s1 s2 =
      let (l1, l2) = ((List.rev (Array.to_list s1)),(List.rev (Array.to_list s2))) in
      let rec max_dim' l1 l2 = 
        match (l1, l2) with
         | ([], []) -> []
         | (x::xs, []) -> x::xs
         | ([], x::xs) -> x::xs
         | (x::xs, y::ys) -> (max x y)::(max_dim' xs ys) in
      List.rev (max_dim' l1 l2) in
    let news = Array.of_list (max_dim s1 s2) in
    match (Array.length s1, Array.length s2, s1=s2) with
        | (0, _, _) -> let newd = (_copy d2 true) in (_elem_mul d1 newd; ref (s2,newd,g2,r2))
        | (_, 0, _) -> let newd = (_copy d1 true) in (_elem_mul newd d2; ref (s1,newd,g1,r1))
        | (_, _, true) -> let newd = (_copy d1 true) in (_elem_mul newd d2; ref (s1,newd,g1,r1))
        | (_, _, _) -> 
          let 
          ((_,t1',g1',r1'),(_,t2',_,_)) = (!(broadcast t1 news true),!(broadcast t2 news true)) in
          (_elem_mul t1' t2'; ref (news,t1',g1',r1'))

  
    (*  
    | (IntScalar r, []) -> IntScalar (f r copy)
 | (FloatScalar r, []) -> FloatScalar (f r copy)
     | (BoolScalar r, []) -> BoolScalar (f r copy)
  
  let broadcast t s copy = let (source, data, grad, grad_fn) = !t in
    let (lead_dim, trail_dim) = _check_broadcastable ) in
    _broadcast t source lead trail copy
  *)
  end 